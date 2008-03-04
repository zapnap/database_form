require File.dirname(__FILE__) + '/../test_helper'

class DatabaseFormPageTest < Test::Unit::TestCase
  fixtures :pages, :form_responses
  test_helper :login, :pages, :difference

  def setup
    @controller = SiteController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as(:existing)
  end

  def test_should_save_form
    assert_difference(FormResponse, :count) do
      post_form
    end
  end

  def test_should_redirect
    post_form
    assert_response :redirect
    assert_equal "/", @response.headers['Location']
  end

  private

  def post_form
    post :show_page, :url => ["contact"], "form_name" => "contact", 
      :redirect_to => "/", :content => { "home_phone" => "111-222-3333", "name" => "nick" }
  end
end
