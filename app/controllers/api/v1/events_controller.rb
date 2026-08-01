module Api
  module V1
    class EventsController < Api::BaseController
      def index
        events = Event.visible_to(current_user)
                      .starting_from(from_time)
                      .chronological
                      .includes(:owner)

        render json: { events: events.map { |record| serialize(record) } }
      end

      private
        # 未指定の場合だけ現在時刻を使う。誤った指定は入口が拒む。
        def from_time
          time_param(:from) || Time.current
        end

        def serialize(event)
          {
            id: event.id,
            title: event.title,
            starts_at: event.starts_at,
            ends_at: event.ends_at,
            all_day: event.all_day,
            visibility: event.visibility,
            owner: { id: event.owner_id, name: event.owner.name }
          }
        end
    end
  end
end
