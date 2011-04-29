class ProviderAuthorizationsController < ApplicationController

  # change the /auth/:provider/callback route to point to this if you want to examine the rack data returned by omniauth
  def auth_callback_test
    render(:text=>request.env['rack.auth'].to_yaml)
  end

  def failure
    flash[:notice] = "Hm, that didn't work. Try again or choose another login option."
    redirect_to login_url
  end

  def create
    auth_info = request.env['rack.auth']
    logger.debug("auth_info: " + auth_info.inspect)
    # omniauth bug sets fb nickname to 'profile.php?id=xxxxx' if no other nickname exists
    if (auth_info["user_info"]["nickname"] && auth_info["user_info"]["nickname"].match("profile.php"))
      auth_info["user_info"]["nickname"] = nil 
    end
    existing_authorization = ProviderAuthorization.find_from_omniauth(auth_info)
    if existing_authorization.nil?  # first time logging in with this provider + provider uid combo
      if current_user # if logged in, link provider to existing inat user
        current_user.add_provider_auth(auth_info)
        flash[:notice] = "You've successfully linked your #{auth_info['provider'].capitalize unless auth_info['provider']=='open_id'} account."
      else # create a new inat user and link provider to that user
        logout_keeping_session!
        self.current_user = User.create_from_omniauth(auth_info)
        handle_remember_cookie! true # set 'remember me' to true
        flash[:notice] = "Welcome!"
        redirect_to edit_login_url and return
      end
    else # existing provider + inat user, so log him in
      self.current_user = existing_authorization.user
      handle_remember_cookie! true # set 'remember me' to true
      flash[:notice] = "Welcome back!"
    end
    if session[:return_to]
      redirect_to session[:return_to] and return
    else
      redirect_back_or_default('/') and return
    end
  end

end