class Unresponsys
  class Row
    extend Forwardable
    delegate [:client] => :table
    attr_reader :table

    def initialize(table, fields)
      @table  = table
      @fields = fields

      @fields.each_pair do |key, val|
        str = key.downcase.chomp('_')
        var = "@#{str}".to_sym
        val = val.to_ruby
        self.instance_variable_set(var, val)

        if key == 'ID_' || key == 'RIID_' || key == "CREATED_DATE_" || key == "UPDATED_DATE_"
          self.class.send(:attr_reader, str)
        else
          self.class.send(:define_method, "#{str}=") do |val|
            val = val.to_ruby
            self.instance_variable_set(var, val)
          end
        end
      end
    end

    def save
      record_data = { fieldNames: [], records: [{ fieldValues: [] }], mapTemplateName: nil }

      to_h.each do |key, val|
        record_data[:fieldNames] << key
        record_data[:records][0][:fieldValues] << val
      end

      options = {
        body: {
          recordData: record_data,
          insertOnNoMatch: true,
          updateOnMatch: 'REPLACE_ALL',
        }
      }

      if @table.supplemental_table?
        url = "/folders/#{@table.folder.name}/suppData/#{@table.name}"
      else
        options[:body][:matchColumn] = 'RIID'
        url = "/lists/#{@table.list.name}/listExtensions/#{@table.name}"
      end

      options[:body] = options[:body].to_json
      r = client.post(url, options)

      if @table.supplemental_table?
        r['errorMessage'].blank?
      else
        r[0]['errorMessage'].blank?
      end
    end

    def destroy
      fail 'Not yet implemented' if @table.extension_table?

      options   = { query: { qa: 'ID_', id: @id.to_responsys, fs: 'all' } }
      response  = @table.client.delete("/folders/#{@table.folder.name}/suppData/#{@table.name}/members", options)

      response['errorMessage'].blank?
    end

    # allow to access custom fields on new record
    def method_missing(sym, *args, &block)
      setter  = sym.to_s.include?('=')
      str     = sym.to_s.chomp('=')
      var     = "@#{str}".to_sym
      val     = args.first

      if setter
        field_name = str.upcase
        @fields[field_name] = ''
        val = val.to_ruby
        self.instance_variable_set(var, val)
      else
        self.instance_variable_get(var)
      end
    end

    def to_h
      hash = {}
      @fields.each_pair do |key, val|
        unless ["CREATED_DATE_", "MODIFIED_DATE_"].include?(key)
          var = "@#{key.downcase.chomp('_')}".to_sym
          val = self.instance_variable_get(var)
          hash[key] = val.to_responsys
        end
      end
      hash
    end
  end
end
