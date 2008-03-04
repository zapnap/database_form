require File.dirname(__FILE__) + '/../test_helper'

class DatabaseFormPageTagsTest < Test::Unit::TestCase
  fixtures :pages, :form_responses
  test_helper :render, :pages

  def setup
    @page = pages(:contact_form)
  end

  def test_form_tag
    assert_render_match(/^\<form.*/, render_form, "contact")
    assert_render_match("name=\"contact\"", render_form, "contact")
    assert_render_match("action=\"/contact/\"", render_form, "contact")
  end

  def test_form_tag_form_name
    assert_render_match("input type=\"hidden\" name=\"form_name\" value=\"contact\"", render_form, "contact")
  end

  def test_form_tag_without_name
    assert_raise(::DatabaseFormPage::DatabaseFormTagError) do
      assert_render_match("form", %Q(<r:database:form></r:database:form>), "contact")
    end
  end

  def test_form_tag_with_redirect
    assert_render_match(%Q(input type="hidden" name="redirect_to" value="/thanks"), render_form("", "redirect_to=\"/thanks\""), "contact")
  end

  def test_form_tag_with_validation
    assert_render_match("validation.js", render_form("", "validate=\"true\""), "contact")
  end

  def test_input_tag
    assert_render_match(%Q(input type="text" name="content\\\[name\\\]"), render_form(%Q(<r:text name="name"/>)), "contact")
  end

  private

  def render_form(content = "", options = "")
    %Q(<r:database:form name="contact" #{options}>#{content}</r:database:form>)
  end
end
