require "openssl"

# その場限りの認証局とサーバー証明書。
#
# HTTPS の経路を、外部の通信も実行環境の信頼設定も使わずに確かめるために作る。
# 作った認証局は、その接続だけへ渡す。OS の信頼設定にも、
# OpenSSL の既定の store にも足さない。足すと、同じプロセスの他の通信まで
# この認証局を信頼してしまう。
#
# 鍵の生成は重いため、1 度だけ作って使い回す。中身は毎回同じでよい。
module LocalCertificateTestHelper
  Bundle = Struct.new(:certificate, :key, :store, keyword_init: true)

  HOSTNAME = "hooks.internal.example".freeze
  OTHER_HOSTNAME = "other.internal.example".freeze

  class << self
    # 正しいホスト名の証明書と、それを信頼する store。
    def trusted
      @trusted ||= issue(HOSTNAME, authority)
    end

    # ホスト名の合わない証明書。信頼する store は同じ。
    def mismatched
      @mismatched ||= issue(OTHER_HOSTNAME, authority)
    end

    # 別の認証局が署名した証明書。上の store では検証できない。
    def untrusted
      @untrusted ||= issue(HOSTNAME, other_authority).then do |bundle|
        Bundle.new(certificate: bundle.certificate, key: bundle.key, store: trusted.store)
      end
    end

    private
      def authority
        @authority ||= build_authority("OfficeWeave Test CA")
      end

      def other_authority
        @other_authority ||= build_authority("OfficeWeave Other CA")
      end

      def build_authority(common_name)
        key = OpenSSL::PKey::RSA.new(2048)
        certificate = OpenSSL::X509::Certificate.new
        certificate.version = 2
        certificate.serial = 1
        certificate.subject = OpenSSL::X509::Name.parse("/CN=#{common_name}")
        certificate.issuer = certificate.subject
        certificate.public_key = key.public_key
        certificate.not_before = Time.now - 3600
        certificate.not_after = Time.now + 3600

        factory = OpenSSL::X509::ExtensionFactory.new
        factory.subject_certificate = certificate
        factory.issuer_certificate = certificate
        certificate.add_extension(factory.create_extension("basicConstraints", "CA:TRUE", true))
        certificate.add_extension(factory.create_extension("keyUsage", "keyCertSign,cRLSign", true))
        certificate.sign(key, OpenSSL::Digest.new("SHA256"))

        [ certificate, key ]
      end

      def issue(hostname, (authority_certificate, authority_key))
        key = OpenSSL::PKey::RSA.new(2048)
        certificate = OpenSSL::X509::Certificate.new
        certificate.version = 2
        certificate.serial = 2
        certificate.subject = OpenSSL::X509::Name.parse("/CN=#{hostname}")
        certificate.issuer = authority_certificate.subject
        certificate.public_key = key.public_key
        certificate.not_before = Time.now - 3600
        certificate.not_after = Time.now + 3600

        factory = OpenSSL::X509::ExtensionFactory.new
        factory.subject_certificate = certificate
        factory.issuer_certificate = authority_certificate
        certificate.add_extension(factory.create_extension("subjectAltName", "DNS:#{hostname}"))
        certificate.sign(authority_key, OpenSSL::Digest.new("SHA256"))

        store = OpenSSL::X509::Store.new
        store.add_cert(authority_certificate)

        Bundle.new(certificate: certificate, key: key, store: store)
      end
  end

  def trusted_certificate = LocalCertificateTestHelper.trusted
  def mismatched_certificate = LocalCertificateTestHelper.mismatched
  def untrusted_certificate = LocalCertificateTestHelper.untrusted
end
