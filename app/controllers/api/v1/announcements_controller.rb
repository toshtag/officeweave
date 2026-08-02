module Api
  module V1
    class AnnouncementsController < Api::BaseController
      def index
        page = paginated(Announcement.visible_to(current_user).recent_first.includes(:author))

        render json: { announcements: page.records.map { |record| serialize(record) },
                       meta: pagination_meta(page) }
      end

      private
        def serialize(announcement)
          {
            id: announcement.id,
            title: announcement.title,
            body: announcement.body,
            visibility: announcement.visibility,
            published_at: announcement.published_at,
            author: { id: announcement.author_id, name: announcement.author.name }
          }
        end
    end
  end
end
