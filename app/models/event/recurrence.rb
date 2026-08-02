class Event < ApplicationRecord
  # 繰り返しの指定と、その回の作成。
  #
  # 予定そのものは Event が持つ。ここが受け持つのは、指定の妥当性と、
  # 各回の作成である。指定は保存しない。保存すると、あとから 1 回だけ
  # 直した予定と、規則の内容が食い違ったまま残る。
  class Recurrence
    include ActiveModel::Validations

    FREQUENCIES = %w[daily weekly monthly].freeze

    # 1 回の操作で作る回数の上限。
    #
    # 上限を置かないと、作る記録の数が指定した日付だけで決まる。
    # 誤って 10 年後を指定した場合に、その分だけ作られる。
    MAXIMUM_OCCURRENCES = 60

    INTERVALS = { "daily" => 1.day, "weekly" => 1.week, "monthly" => 1.month }.freeze

    attr_reader :event, :frequency, :repeat_until

    validates :frequency, inclusion: { in: FREQUENCIES }, if: :frequency_given?
    validate :repeat_until_must_be_present, if: :frequency_given?
    validate :repeat_until_must_not_precede_start, if: :repeating?
    validate :occurrences_must_not_exceed_maximum, if: :repeating?

    def initialize(event, frequency: nil, repeat_until: nil)
      @event = event
      @frequency = frequency.presence
      @repeat_until = repeat_until.presence
    end

    # 繰り返しの指定があるか。無い場合は 1 件だけ作る。
    def repeating? = frequency_given? && repeat_until.present? && FREQUENCIES.include?(frequency)

    def frequency_given? = frequency.present?

    # 最初の回を保存し、続く回を作る。
    def save(participants: [])
      return false unless valid?

      Event.transaction do
        raise ActiveRecord::Rollback unless event.save

        event.invite(users: participants, actor: event.owner)
        # 最初の回も自分の識別子を持つ。繰り返しの一部かどうかの判定を
        # 「最初の回だけ別」にしない。
        event.update_column(:series_id, event.id) if repeating?
        create_following(participants)
      end

      event.persisted?
    end

    private
      def occurrence_starts
        return [] unless repeating?

        interval = INTERVALS.fetch(frequency)
        starts = []
        at = event.starts_at + interval

        while at.to_date <= repeat_until.to_date && starts.size < MAXIMUM_OCCURRENCES
          starts << at
          at += interval
        end

        starts
      end

      # 続く回は最初の回の複製とする。属性を選んで写すと、予定へ列を足した
      # ときに写し忘れる。
      def create_following(participants)
        duration = event.ends_at - event.starts_at

        occurrence_starts.each do |starts_at|
          occurrence = event.dup
          occurrence.starts_at = starts_at
          occurrence.ends_at = starts_at + duration
          occurrence.series_id = event.id
          occurrence.department_ids = event.department_ids
          occurrence.save!
          occurrence.invite(users: participants, actor: event.owner)
        end
      end

      def repeat_until_must_be_present
        return if repeat_until.present?

        errors.add(:repeat_until, :blank)
      end

      def repeat_until_must_not_precede_start
        return if event.starts_at.nil? || repeat_until.to_date >= event.starts_at.to_date

        errors.add(:repeat_until, :not_after_start)
      end

      def occurrences_must_not_exceed_maximum
        return if errors.any?
        return if occurrence_starts.size < MAXIMUM_OCCURRENCES

        errors.add(:repeat_until, :too_many_occurrences)
      end
  end
end
