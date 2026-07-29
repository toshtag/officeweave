module Api
  module V1
    class AnnouncementsController < Api::BaseController
      def index
        announcements = Announcement.visible_to(current_user).recent_first.includes(:author)

        render json: { announcements: announcements.map { |record| serialize(record) } }
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
