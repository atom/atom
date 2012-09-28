class Notifier < ActionMailer::Base
  def forgot_password(user, url)
    # Email header info
    @subject += "Forgotten password notification"
  end
end
