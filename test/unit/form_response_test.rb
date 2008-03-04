require File.dirname(__FILE__) + '/../test_helper'

class FormResponseTest < Test::Unit::TestCase
  def setup
    @form_response = FormResponse.new(:name => "contact", :content => { 'name' => "name", 'email' => "email@test.net" })
  end

  def test_validation
    assert @form_response.valid?
  end

  def test_validation_requires_name
    @form_response = FormResponse.new
    assert !@form_response.valid?
    assert_equal "can't be blank", @form_response.errors.on(:name)
  end

  def test_validation_requires_content
    @form_response = FormResponse.new
    assert !@form_response.valid?
    assert_equal "can't be blank", @form_response.errors.on(:content)
  end

  def test_serialized_content_to_hash
    @form_response.save
    assert_equal "email@test.net", @form_response.reload.content['email']
  end

  def test_to_xml
    @form_response.save
    assert_match "<name>#{@form_response.content['name']}</name>", @form_response.to_xml
    assert_match "<email>#{@form_response.content['email']}</email>", @form_response.to_xml
  end
end
