require "yaml"

# 機能到達度の一覧を、判定の型を解いた形で読む。
#
# 同じ判定を持つ機能が多いため、一覧は判定の型（`criterion_profiles`）を持つ。
# 機能の側は条件の名前を並べたうえで、判定が型と同じ場合だけ型を指す。
#
# 読む側がそのたびに型をたどると、たどり忘れた検査が「判定が無い」と誤って
# 通す。解くのはここ 1 か所とする。
module CapabilityRegistryTestHelper
  PATH = Rails.root.join("docs/product/capability_registry.yml")

  module_function

  # 生の一覧。型そのものを確かめる検査が使う。
  def raw_registry = YAML.safe_load_file(PATH)

  # 判定の型を解いた一覧。
  def registry
    document = raw_registry
    profiles = document.fetch("criterion_profiles")

    document.fetch("capabilities").each do |capability|
      capability["criteria"] = capability.fetch("criteria").to_h do |name, judgement|
        [ name, resolve(name, judgement, profiles, capability.fetch("id")) ]
      end
    end

    document
  end

  def resolve(name, judgement, profiles, owner)
    id = judgement["profile"]

    return judgement if id.nil?

    profile = profiles[id]

    raise KeyError, "#{owner} の #{name} が指す判定の型がありません: #{id}" if profile.nil?

    profile.except("criterion")
  end
end
