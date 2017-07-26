class PagesController < ApplicationController
  layout "pages"

  def home
    @contact = Contact.new
  end
  
end 