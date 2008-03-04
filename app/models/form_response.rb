class FormResponse < ActiveRecord::Base
  validates_presence_of :name, :content
  serialize :content, Hash

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    xml.tag!("form-response", :id => id) do
      xml.tag!("created-at", created_at.strftime("%Y-%m-%d %H:%M"))
      content.each do |name, value|
        xml.tag!(name.dasherize, value)
      end
    end
  end
end
