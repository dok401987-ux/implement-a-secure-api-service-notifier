require 'sinatra'
require 'active_support/notifications'
require 'securerandom'
require 'digest'

class SecureApiNotifier
  def self.configure
    @api_key = ENV['API_KEY']
    @api_secret = ENV['API_SECRET']
    @notifications = ActiveSupport::Notifications.subscribe('service_notifier') do |*args|
      event = ActiveSupport::Notifications::Event.new *args
      notifiable = event.payload[:notifiable]
      notify_securely(notifiable)
    end
  end

  def self.notify_securely(notifiable)
    signature = sign(notifiable)
    notify_api(notifiable, signature)
  end

  def self.sign(notifiable)
    message = "#{notifiable.class.name} #{notifiable.id}"
    Digest::SHA256.hexdigest("#{message}#{@api_secret}").upcase
  end

  def self.notify_api(notifiable, signature)
    headers = {
      'API-Key' => @api_key,
      'Signature' => signature
    }
    body = notifiable.to_json

    begin
      response = RestClient.post 'https://api.example.com/notify', body, headers
      Rails.logger.info "Sent notification to API: #{response.code}"
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "Error sending notification to API: #{e.response.code}"
    end
  end
end

SecureApiNotifier.configure

post '/notify' do
  notifiable = Notifiable.find(params[:id])
  SecureApiNotifier.notify_securely(notifiable)
  'Notification sent successfully!'
end