require 'twitter/rest/request'

module Twitter
  module REST
    module UploadUtils


      # Uploads images and videos. Videos require multiple requests and uploads in chunks of 5 Megabytes.
      # The only supported video format is mp4.
      #
      # @see https://dev.twitter.com/rest/public/uploading-media
      # @param media [File] The file to be uploaded (PNG, JPG, GIF & MP4)
      # @param media_category_prefix [text] The prefix for the media object category (tweet, dm)
      # @param shared [boolean] Flag to determine whether the media object can be reused (true, false)
      def upload(media, media_category_prefix: 'tweet', shared: false)
        return chunk_upload(media, 'video/mp4', "#{media_category_prefix}_video", shared) if File.extname(media) == '.mp4'
        return chunk_upload(media, 'image/gif', "#{media_category_prefix}_gif", shared) if File.extname(media) == '.gif' && File.size(media) > 5_000_000

        Twitter::REST::Request.new(self, :multipart_post, 'https://upload.twitter.com/1.1/media/upload.json', key: :media, file: media).perform
      end

      private
      # rubocop:disable MethodLength
      def chunk_upload(media, media_type, media_category, shared)
        init = Twitter::REST::Request.new(self, :post, 'https://upload.twitter.com/1.1/media/upload.json',
                                          command: 'INIT',
                                          shared: shared,
                                          media_type: media_type,
                                          media_category: media_category,
                                          total_bytes: media.size).perform

        until media.eof?
          chunk = media.read(5_000_000)
          seg ||= -1
          Twitter::REST::Request.new(self, :multipart_post, 'https://upload.twitter.com/1.1/media/upload.json',
                                     command: 'APPEND',
                                     media_id: init[:media_id],
                                     segment_index: seg += 1,
                                     key: :media,
                                     file: StringIO.new(chunk)).perform
        end

        media.close

        Twitter::REST::Request.new(self, :post, 'https://upload.twitter.com/1.1/media/upload.json',
                                   command: 'FINALIZE', media_id: init[:media_id]).perform
      end
      # rubocop:enable MethodLength
    end
  end
end
