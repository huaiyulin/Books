class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :verify_identity_token

  private

  def verify_identity_token
    # skip this on test and auth callbacks
    return if Rails.env.test?
    return if params[:controller] == 'users/omniauth_callbacks'
    request_identity_token = cookies[:_identity_token]

    if user_signed_in?

      # if the user's session is valid but the identity_token is blank,
      # sign out the user
      if request_identity_token.blank?
        sign_out current_user

      # if the user's session is valid and the identity_token is blank,
      # check if the identity_token is valid
      else
        # split it and get the hash & timestamp
        request_identity_token_split = request_identity_token.split('.')
        request_identity_token_hash = request_identity_token_split[0]
        request_identity_token_timestamp = request_identity_token_split[1]
        token_generate_time = Time.at(request_identity_token_timestamp.to_i)

        # generate a token with provided parameters to compare it with the identity_token
        identity_token_hash = Digest::MD5.hexdigest(current_user.sid.to_s + Digest::MD5.hexdigest(identity_token_secret_key + request_identity_token_timestamp))

        # check if they're matched, sign out the user if isn't
        if request_identity_token_hash != identity_token_hash
          sign_out current_user
          token_generate_time = Time.at(0)
        end

        # if the token is too old and the current HTTP method is redirectable,
        # redirect to core to refresh it
        # refresh it anyway if the token has expired
        if (Time.now - token_generate_time > 7.days) ||
           (Time.now - token_generate_time > 3.days && request.get?)
          redirect_to ENV['CORE_URL'] + "/refresh_it?redirect_to=#{CGI.escape(request.original_url)}"
        end
      end

    # if the user isn't signed in but the identity_token isn't blank,
    # redirect to core authorize path
    elsif !request_identity_token.blank?
      redirect_to user_omniauth_authorize_path(:colorgy)
    end
  end

  def identity_token_secret_key
    @site_secret ||= Digest::MD5.hexdigest(ENV['SITE_SECRET'])[0..16]
  end
end
