class DatabaseFormPage < Page
  class DatabaseFormTagError < StandardError; end
 
  attr_reader :form_name, :form_error, :form_data, :tag_attr

  # Page processing. If the page has posted-back, it will try to save to contacts 
  # table and redirect to a different page, if specified.
  def process(request, response)
    @request, @response = request, response
    @form_name, @form_error = nil, nil
    if request.post?
      @form_data = request.parameters[:content].to_hash

      # Remove certain fields from hash
      form_data.delete("Submit")  
      form_data.delete("Ignore")  
      form_data.delete_if { |key, value| key.match(/_verify$/) }

      @form_name = request.parameters[:form_name]
      redirect_to = request.parameters[:redirect_to]

      if save_form and redirect_to
        response.redirect(redirect_to)
      else
        super(request, response) 
      end
    else
      super(request, response)
    end
  end
 
  # Save form data
  def save_form
    form_response = FormResponse.new(:name => form_name)
    form_response.content = form_data
    if !form_response.save
      @form_error = "Error encountered while trying to submit form. #{$!}"
      false
    else 
      true
    end
  end
 
  # Don't cache this page!
  def cache?
    false
  end
  
  # DatabaseForm Tags:
    
    desc %{ 
      Creates the @<r:database/>@ namespace See @<r:database:form>...</r:database:form>@. 
    }
    tag 'database' do |tag|
      tag.expand
    end
    
    desc %{ 
      The @<r:database:form>...</r:database:form>@ should include all of the 
      helper tags for creating form fields. The @name@ attribute is required. The
      @return_to@ attribute can be used to specify an optional return URL that the user
      will be redirected to after submission. The @validate@ attribute can be used to
      enable client-side JavaScript form validation. Individual helper tags must declare
      the kind of validation that should be performed on them using a @validate@ 
      attribute as well (possible values: @required@, @validate-number@, @validate-digits@,
      @validate-alpha@, @validate-alphanum@, @validate-date@, @validate-email@,
      @validate-url@, @validate-currency-dollar@, @validate-selection@, 
      @validate-one-required@).

      *Usage:*
      <pre><code><r:database:form name="contact" return_to="/contact/thank-you" validate="true">
        <r:text name="name" validate="required validate-alpha"/>
        <r:text name="email" validate="required validate-email"/>
        <r:submit/>
      </r:database:form></code></pre>
    }
    tag 'database:form' do |tag|
      @tag_attr = tag.attr.symbolize_keys
      tag.locals.validate = tag_attr[:validate]
      raise_error_if_name_missing("database:form")

      # Build the html form tag...
      results = %Q(<form action="#{url}" method="post" class="#{tag_attr[:class]}" enctype="multipart/form-data" id="#{tag_attr[:name]}" name="#{tag_attr[:name]}">)

      if tag.locals.validate
        results << %Q(<script src="/javascripts/validation.js" type="text/javascript"></script>)
        results << %Q(<script type="text/javascript">)
        results << %Q(function formCallback(result, form) { if (result == true) { $('#{tag_attr[:name]}').submit(); } })
        results << %Q(var valid = new Validation('#{tag_attr[:name]}', { immediate: false, onFormValidate: formCallback });)
        results << %Q(</script>)
      end

      results << %Q(<input type="hidden" name="form_name" value="#{tag_attr[:name]}" />)
      results << %Q(<input type="hidden" name="redirect_to" value="#{tag_attr[:redirect_to]}" />) unless tag_attr[:redirect_to].nil?
      results << %Q(<div class="database-error">#{form_error}</div>) if form_error
      results << tag.expand
      results << %Q(</form>)
    end
 
    # Build tags for all of the <input /> tags...
    %w(text password file submit reset checkbox radio hidden).each do |type|
      desc %{ 
        Renders a @<#{type}>@ form control for a database form.
      }
      tag "database:#{type}" do |tag|
        @tag_attr = tag.attr.symbolize_keys
        raise_error_if_name_missing("database:#{type}") unless %(submit reset).include?(type)
        @tag_attr[:onclick] = "valid.validate(); return false" if tag.locals.validate and type == 'submit'
        @tag_attr[:onclick] = "valid.reset();" if tag.locals.validate and type == 'reset'
        input_tag_html(type)
      end      
    end
 
    desc %{ 
      Renders a @<select>...</select>@ form control. This is used with the
      the @<r:database:option/>@ tag to build selection lists.
    }
    tag 'database:select' do |tag|
      @tag_attr = { :id => tag.attr['name'], :size => '1' }.update(tag.attr.symbolize_keys)
      raise_error_if_name_missing("database:select")
      tag.locals.parent_tag_name = tag_attr[:name]
      tag.locals.parent_tag_type = "select"
      results =  %Q(<select name="content[#{tag_attr[:name]}]" #{add_attrs_to("")}>)
      results << tag.expand
      results << "</select>"
    end
 
    desc %{ 
      Renders a @<textarea>...</textarea>@ form control.
    }
    tag 'database:textarea' do |tag|
      @tag_attr = { :id => tag.attr['name'], :rows => '5', :cols => '35' }.update(tag.attr.symbolize_keys)
      raise_error_if_name_missing("database:textarea")
      results =  %Q(<textarea name="content[#{tag_attr[:name]}]" #{add_attrs_to("")}>)
      results << tag.expand
      results << "</textarea>"
    end
    
    %{ 
      Special tag for radio groups. Works with the @<r:database:option/>@ tag. 
    }
    tag 'database:radiogroup' do |tag|
      @tag_attr = tag.attr.symbolize_keys
      raise_error_if_name_missing("database:radiogroup")
      tag.locals.parent_tag_name = tag_attr[:name]
      tag.locals.parent_tag_type = 'radiogroup'
      tag.expand
    end
 
    desc %{ 
      Custom tag for rendering an @<option/>@ tag if the parent is a 
      @<select>...</select>@ tag, or rendering an @<input type="radio"/>@ tag
      if the parent is a @<r:database:radiogroup>...</r:database:radiogroup>@. 
    }
    tag 'database:option' do |tag|
      @tag_attr = tag.attr.symbolize_keys
      raise_error_if_name_missing("database:option")
      result = ""
      if tag.locals.parent_tag_type == 'select'
        result << %Q(<option value="#{tag_attr.delete(:value) || tag_attr[:name]}" #{add_attrs_to("")}>#{tag_attr[:name]}</option>)
      elsif tag.locals.parent_tag_type == 'radiogroup'
        tag.globals.option_count = tag.globals.option_count.nil? ? 1 : tag.globals.option_count += 1
        options = tag_attr.clone.update({
          :id => "#{tag.locals.parent_tag_name}_#{tag.globals.option_count}",
          :value => tag_attr.delete(:value) || tag_attr[:name],
          :name => tag.locals.parent_tag_name
        })
        result << input_tag_html('radio', options)
        result << %Q(<label for="#{options[:id]}">#{tag_attr[:name]}</label>)
      end
    end
 
    desc %{ 
      Renders an option list of US states. Use between the appropriate
      @<select>...<select/>@ tags. 
    }
    tag 'database:us_states' do |tag|
      results = %Q(<option value="AL">AL</option>)
      results << %Q(<option value="AK">AK</option>)
      results << %Q(<option value="AZ">AZ</option>)
      results << %Q(<option value="AR">AR</option>)
      results << %Q(<option value="CA">CA</option>)
      results << %Q(<option value="CO">CO</option>)
      results << %Q(<option value="CT">CT</option>)
      results << %Q(<option value="DE">DE</option>)
      results << %Q(<option value="DC">DC</option>)
      results << %Q(<option value="FL">FL</option>)
      results << %Q(<option value="GA">GA</option>)
      results << %Q(<option value="HI">HI</option>)
      results << %Q(<option value="ID">ID</option>)
      results << %Q(<option value="IL">IL</option>)
      results << %Q(<option value="IN">IN</option>)
      results << %Q(<option value="IA">IA</option>)
      results << %Q(<option value="KS">KS</option>)
      results << %Q(<option value="KY">KY</option>)
      results << %Q(<option value="LA">LA</option>)
      results << %Q(<option value="ME">ME</option>)
      results << %Q(<option value="MD">MD</option>)
      results << %Q(<option value="MA">MA</option>)
      results << %Q(<option value="MI">MI</option>)
      results << %Q(<option value="MN">MS</option>)
      results << %Q(<option value="MS">MS</option>)
      results << %Q(<option value="MO">MO</option>)
      results << %Q(<option value="MT">MT</option>)
      results << %Q(<option value="NE">NE</option>)
      results << %Q(<option value="NV">NV</option>)
      results << %Q(<option value="NH">NH</option>)
      results << %Q(<option value="NJ">NJ</option>)
      results << %Q(<option value="NM">NM</option>)
      results << %Q(<option value="NY">NY</option>)
      results << %Q(<option value="NC">NC</option>)
      results << %Q(<option value="ND">ND</option>)
      results << %Q(<option value="OH">OH</option>)
      results << %Q(<option value="OK">OK</option>)
      results << %Q(<option value="OR">OR</option>)
      results << %Q(<option value="PA">PA</option>)
      results << %Q(<option value="RI">RI</option>)
      results << %Q(<option value="SC">SC</option>)
      results << %Q(<option value="SD">SD</option>)
      results << %Q(<option value="TN">TN</option>)
      results << %Q(<option value="TX">TX</option>)
      results << %Q(<option value="UT">UT</option>)
      results << %Q(<option value="VT">VT</option>)
      results << %Q(<option value="VA">VA</option>)
      results << %Q(<option value="WA">WA</option>)
      results << %Q(<option value="WV">WV</option>)
      results << %Q(<option value="WI">WI</option>)
      results << %Q(<option value="WY">WY</option>)
    end

    desc %{ 
      Renders an option list of Canadian provinces. Use between appropriate
      @<select>...</select>@ tags. 
    }
    tag 'database:ca_provinces' do |tag|
      results = %Q(<option value="AB">AB</option>)
      results << %Q(<option value="BC">BC</option>)
      results << %Q(<option value="MB">MB</option>)
      results << %Q(<option value="NB">NB</option>)
      results << %Q(<option value="NL">NL</option>)
      results << %Q(<option value="NT">NT</option>)
      results << %Q(<option value="NU">NU</option>)
      results << %Q(<option value="ON">ON</option>)
      results << %Q(<option value="PE">PE</option>)
      results << %Q(<option value="QC">QC</option>)
      results << %Q(<option value="SK">SK</option>)
      results << %Q(<option value="YT">YT</option>)
    end

    desc %{ 
      Renders an option list of countries. Use between appropriate
      @<select>...</select>@ tags. 
    }
    tag 'database:countries' do |tag|
      results = %Q{<option value="United States">United States</option>}
      results << %Q{<option value="Afghanistan">Afghanistan</option>}
      results << %Q{<option value="Albania">Albania</option>}
      results << %Q{<option value="Algeria">Algeria</option>}
      results << %Q{<option value="American Samoa">American Samoa</option>}
      results << %Q{<option value="Andorra">Andorra</option>}
      results << %Q{<option value="Angola">Angola</option>}
      results << %Q{<option value="Anguilla">Anguilla</option>}
      results << %Q{<option value="Antarctica">Antarctica</option>}
      results << %Q{<option value="Antigua and Barbuda">Antigua and Barbuda</option>}
      results << %Q{<option value="Argentina">Argentina</option>}
      results << %Q{<option value="Armenia">Armenia</option>}
      results << %Q{<option value="Aruba">Aruba</option>}
      results << %Q{<option value="Australia">Australia</option>}
      results << %Q{<option value="Austria">Austria</option>}
      results << %Q{<option value="Azerbaijan">Azerbaijan</option>}
      results << %Q{<option value="Bahamas">Bahamas</option>}
      results << %Q{<option value="Bahrain">Bahrain</option>}
      results << %Q{<option value="Bangladesh">Bangladesh</option>}
      results << %Q{<option value="Barbados">Barbados</option>}
      results << %Q{<option value="Belarus">Belarus</option>}
      results << %Q{<option value="Belgium">Belgium</option>}
      results << %Q{<option value="Belize">Belize</option>}
      results << %Q{<option value="Benin">Benin</option>}
      results << %Q{<option value="Bermuda">Bermuda</option>}
      results << %Q{<option value="Bhutan">Bhutan</option>}
      results << %Q{<option value="Bolivia">Bolivia</option>}
      results << %Q{<option value="Bosnia and Herzegowina">Bosnia and Herzegowina</option>}
      results << %Q{<option value="Botswana">Botswana</option>}
      results << %Q{<option value="Brazil">Brazil</option>}
      results << %Q{<option value="Brunei">Brunei</option>}
      results << %Q{<option value="Bulgaria">Bulgaria</option>}
      results << %Q{<option value="Burkina Faso">Burkina Faso</option>}
      results << %Q{<option value="Burundi">Burundi</option>}
      results << %Q{<option value="Cambodia">Cambodia</option>}
      results << %Q{<option value="Cameroon">Cameroon</option>}
      results << %Q{<option value="Canada">Canada</option>}
      results << %Q{<option value="Cape Verde">Cape Verde</option>}
      results << %Q{<option value="Cayman Islands">Cayman Islands</option>}
      results << %Q{<option value="Central African Republic">Central African Republic</option>}
      results << %Q{<option value="Chad">Chad</option>}
      results << %Q{<option value="Chile">Chile</option>}
      results << %Q{<option value="China">China</option>}
      results << %Q{<option value="Colombia">Colombia</option>}
      results << %Q{<option value="Congo">Congo</option>}
      results << %Q{<option value="Cook Islands">Cook Islands</option>}
      results << %Q{<option value="Costa Rica">Costa Rica</option>}
      results << %Q{<option value="Cote d\'Ivoire">Cote d\'Ivoire</option>}
      results << %Q{<option value="Croatia (Hrvatska)">Croatia (Hrvatska)</option>}
      results << %Q{<option value="Cyprus">Cyprus</option>}
      results << %Q{<option value="Czech Republic">Czech Republic</option>}
      results << %Q{<option value="Denmark">Denmark</option>}
      results << %Q{<option value="Djibouti">Djibouti</option>}
      results << %Q{<option value="Dominica">Dominica</option>}
      results << %Q{<option value="Dominican Republic">Dominican Republic</option>}
      results << %Q{<option value="East Timor">East Timor</option>}
      results << %Q{<option value="Ecuador">Ecuador</option>}
      results << %Q{<option value="Egypt">Egypt</option>}
      results << %Q{<option value="El Salvador">El Salvador</option>}
      results << %Q{<option value="Equatorial Guinea">Equatorial Guinea</option>}
      results << %Q{<option value="Eritrea">Eritrea</option>}
      results << %Q{<option value="Estonia">Estonia</option>}
      results << %Q{<option value="Ethiopia">Ethiopia</option>}
      results << %Q{<option value="Falkland Islands">Falkland Islands</option>}
      results << %Q{<option value="Fiji">Fiji</option>}
      results << %Q{<option value="Finland">Finland</option>}
      results << %Q{<option value="France">France</option>}
      results << %Q{<option value="French Guiana">French Guiana</option>}
      results << %Q{<option value="French Polynesia">French Polynesia</option>}
      results << %Q{<option value="Gabon">Gabon</option>}
      results << %Q{<option value="Gambia">Gambia</option>}
      results << %Q{<option value="Georgia">Georgia</option>}
      results << %Q{<option value="Germany">Germany</option>}
      results << %Q{<option value="Ghana">Ghana</option>}
      results << %Q{<option value="Gibraltar">Gibraltar</option>}
      results << %Q{<option value="Greece">Greece</option>}
      results << %Q{<option value="Greenland">Greenland</option>}
      results << %Q{<option value="Grenada">Grenada</option>}
      results << %Q{<option value="Guadeloupe">Guadeloupe</option>}
      results << %Q{<option value="Guam">Guam</option>}
      results << %Q{<option value="Guatemala">Guatemala</option>}
      results << %Q{<option value="Guinea">Guinea</option>}
      results << %Q{<option value="Guinea-Bissau">Guinea-Bissau</option>}
      results << %Q{<option value="Guyana">Guyana</option>}
      results << %Q{<option value="Haiti ">Haiti </option>}
      results << %Q{<option value="Honduras">Honduras</option>}
      results << %Q{<option value="Hong Kong">Hong Kong</option>}
      results << %Q{<option value="Hungary">Hungary</option>}
      results << %Q{<option value="Iceland">Iceland</option>}
      results << %Q{<option value="India">India</option>}
      results << %Q{<option value="Indonesia">Indonesia</option>}
      results << %Q{<option value="Iran">Iran</option>}
      results << %Q{<option value="Iraq">Iraq</option>}
      results << %Q{<option value="Ireland">Ireland</option>}
      results << %Q{<option value="Israel">Israel</option>}
      results << %Q{<option value="Italy">Italy</option>}
      results << %Q{<option value="Jamaica">Jamaica</option>}
      results << %Q{<option value="Japan">Japan</option>}
      results << %Q{<option value="Jordan">Jordan</option>}
      results << %Q{<option value="Kazakhstan">Kazakhstan</option>}
      results << %Q{<option value="Kenya">Kenya</option>}
      results << %Q{<option value="Kiribati">Kiribati</option>}
      results << %Q{<option value="South Korea">South Korea</option>}
      results << %Q{<option value="Kuwait">Kuwait</option>}
      results << %Q{<option value="Kyrgyzstan">Kyrgyzstan</option>}
      results << %Q{<option value="Laos">Laos</option>}
      results << %Q{<option value="Latvia">Latvia</option>}
      results << %Q{<option value="Lebanon">Lebanon</option>}
      results << %Q{<option value="Lesotho">Lesotho</option>}
      results << %Q{<option value="Liberia">Liberia</option>}
      results << %Q{<option value="Libya">Libya</option>}
      results << %Q{<option value="Liechtenstein">Liechtenstein</option>}
      results << %Q{<option value="Lithuania">Lithuania</option>}
      results << %Q{<option value="Luxembourg">Luxembourg</option>}
      results << %Q{<option value="Macau">Macau</option>}
      results << %Q{<option value="Macedonia">Macedonia</option>}
      results << %Q{<option value="Madagascar">Madagascar</option>}
      results << %Q{<option value="Malawi">Malawi</option>}
      results << %Q{<option value="Malaysia">Malaysia</option>}
      results << %Q{<option value="Maldives">Maldives</option>}
      results << %Q{<option value="Mali">Mali</option>}
      results << %Q{<option value="Malta">Malta</option>}
      results << %Q{<option value="Martinique">Martinique</option>}
      results << %Q{<option value="Mauritania">Mauritania</option>}
      results << %Q{<option value="Mauritius">Mauritius</option>}
      results << %Q{<option value="Mexico">Mexico</option>}
      results << %Q{<option value="Micronesia">Micronesia</option>}
      results << %Q{<option value="Moldova">Moldova</option>}
      results << %Q{<option value="Monaco">Monaco</option>}
      results << %Q{<option value="Mongolia">Mongolia</option>}
      results << %Q{<option value="Montenegro">Montenegro</option>}
      results << %Q{<option value="Montserrat">Montserrat</option>}
      results << %Q{<option value="Morocco">Morocco</option>}
      results << %Q{<option value="Mozambique">Mozambique</option>}
      results << %Q{<option value="Namibia">Namibia</option>}
      results << %Q{<option value="Nepal">Nepal</option>}
      results << %Q{<option value="Netherlands">Netherlands</option>}
      results << %Q{<option value="New Zealand">New Zealand</option>}
      results << %Q{<option value="Nicaragua">Nicaragua</option>}
      results << %Q{<option value="Niger">Niger</option>}
      results << %Q{<option value="Nigeria">Nigeria</option>}
      results << %Q{<option value="Norway">Norway</option>}
      results << %Q{<option value="Oman">Oman</option>}
      results << %Q{<option value="Pakistan">Pakistan</option>}
      results << %Q{<option value="Panama">Panama</option>}
      results << %Q{<option value="Papua New Guinea">Papua New Guinea</option>}
      results << %Q{<option value="Paraguay">Paraguay</option>}
      results << %Q{<option value="Peru">Peru</option>}
      results << %Q{<option value="Philippines">Philippines</option>}
      results << %Q{<option value="Poland">Poland</option>}
      results << %Q{<option value="Portugal">Portugal</option>}
      results << %Q{<option value="Puerto Rico">Puerto Rico</option>}
      results << %Q{<option value="Qatar">Qatar</option>}
      results << %Q{<option value="Romania">Romania</option>}
      results << %Q{<option value="Russia">Russia</option>}
      results << %Q{<option value="Rwanda">Rwanda</option>}
      results << %Q{<option value="Saudi Arabia">Saudi Arabia</option>}
      results << %Q{<option value="Senegal">Senegal</option>}
      results << %Q{<option value="Serbia">Serbia</option>}
      results << %Q{<option value="Seychelles">Seychelles</option>}
      results << %Q{<option value="Sierra Leone">Sierra Leone</option>}
      results << %Q{<option value="Singapore">Singapore</option>}
      results << %Q{<option value="Slovakia">Slovakia</option>}
      results << %Q{<option value="Slovenia">Slovenia</option>}
      results << %Q{<option value="Somalia">Somalia</option>}
      results << %Q{<option value="South Africa">South Africa</option>}
      results << %Q{<option value="Spain">Spain</option>}
      results << %Q{<option value="Sri Lanka">Sri Lanka</option>}
      results << %Q{<option value="Sudan">Sudan</option>}
      results << %Q{<option value="Suriname">Suriname</option>}
      results << %Q{<option value="Swaziland">Swaziland</option>}
      results << %Q{<option value="Sweden">Sweden</option>}
      results << %Q{<option value="Switzerland">Switzerland</option>}
      results << %Q{<option value="Syria">Syria</option>}
      results << %Q{<option value="Taiwan">Taiwan</option>}
      results << %Q{<option value="Tajikistan">Tajikistan</option>}
      results << %Q{<option value="Tanzania">Tanzania</option>}
      results << %Q{<option value="Thailand">Thailand</option>}
      results << %Q{<option value="The Vatican">The Vatican</option>}
      results << %Q{<option value="Togo">Togo</option>}
      results << %Q{<option value="Trinidad and Tobago">Trinidad and Tobago</option>}
      results << %Q{<option value="Tunisia">Tunisia</option>}
      results << %Q{<option value="Turkey">Turkey</option>}
      results << %Q{<option value="Turkmenistan">Turkmenistan</option>}
      results << %Q{<option value="Uganda">Uganda</option>}
      results << %Q{<option value="Ukraine">Ukraine</option>}
      results << %Q{<option value="United Arab Emirates">United Arab Emirates</option>}
      results << %Q{<option value="United Kingdom">United Kingdom</option>}
      results << %Q{<option value="Uruguay">Uruguay</option>}
      results << %Q{<option value="Uzbekistan">Uzbekistan</option>}
      results << %Q{<option value="Venezuela">Venezuela</option>}
      results << %Q{<option value="Viet Nam">Viet Nam</option>}
      results << %Q{<option value="Virgin Islands (British)">Virgin Islands (British)</option>}
      results << %Q{<option value="Virgin Islands (U.S.)">Virgin Islands (U.S.)</option>}
      results << %Q{<option value="Western Sahara">Western Sahara</option>}
      results << %Q{<option value="Yemen">Yemen</option>}
      results << %Q{<option value="Zambia">Zambia</option>}
    end

  protected
 
  def input_tag_html(type, opts=tag_attr)
    options = { :id => tag_attr[:name], :value => "" }.update(opts)
    results =  %Q(<input type="#{type}" )
    results << %Q(name="content[#{options[:name]}]" ) if tag_attr[:name]
    results << %Q(#{add_attrs_to("", options)}/>)
  end
  
  def add_attrs_to(results, tag_attrs=tag_attr)
    attrs_to_add = tag_attrs.stringify_keys
    attrs_to_add['class'] = (attrs_to_add['class'].to_s  + " #{attrs_to_add.delete('validate')}") if attrs_to_add['validate']

    attrs_to_add.sort.each do |name, value|
      results << %Q(#{name.to_s}="#{value.to_s}" ) unless name == 'name'
    end
    results
  end
  
  def raise_name_error(tag_name)
    raise(DatabaseFormTagError.new("`#{tag_name}' tag requires a `name' attribute"))
  end

  def raise_error_if_name_missing(tag_name)
    raise_name_error(tag_name) if tag_attr[:name].nil? or tag_attr[:name].empty?
  end
end
