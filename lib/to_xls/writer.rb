require 'rubygems'
require 'stringio'
require 'spreadsheet'

module ToXls

  class Writer
    def initialize(array, options = {})
      @array = array
      @options = options
      @cell_format = create_format :cell_format
      @header_format = create_format :header_format
    end

    def write_string(string = '')
      io = StringIO.new(string)
      write_io(io)
      io.string
    end

    def write_io(io)
      book = Spreadsheet::Workbook.new
      write_book(book)
      book.write(io)
    end

    def write_book(book)
      sheet = book.create_worksheet
      sheet.name = @options[:name] || 'Sheet 1'
      write_sheet(sheet)
      return book
    end

    def write_sheet(sheet)
      if columns.any?
        row_index = 0

        if headers_should_be_included?
          if @options.has_key?(:fixed_columns) && @options[:fixed_columns]
            columns.each_with_index do |col, idx_col|
              sheet.column(idx_col).width = col.to_s.strip.size if (col.is_a?(Symbol) || col.is_a?(String)) && !col.nil? && sheet.column(idx_col).width < col.to_s.strip.size
            end
          end
          apply_format_to_row(sheet.row(0), @header_format)
          fill_row(sheet.row(0), headers)
          row_index = 1
        end

        @array.each do |model|
          if @options.has_key?(:fixed_columns) && @options[:fixed_columns]
            columns.each_with_index do |col, idx_col|
              column_size = model_column_to_s(model.send(col)).try(:strip).try(:size)
              sheet.column(idx_col).width = column_size if (col.is_a?(Symbol) || col.is_a?(String)) && !model.send(col).nil? && sheet.column(idx_col).width < column_size
            end
          end
          row = sheet.row(row_index)
          apply_format_to_row(row, @cell_format)
          fill_row(row, columns, model)
          row_index += 1
        end
      end
    end

    def columns
      return  @columns if @columns
      @columns = @options[:columns]
      raise ArgumentError.new(":columns (#{columns}) must be an array or nil") unless (@columns.nil? || @columns.is_a?(Array))
      @columns ||=  can_get_columns_from_first_element? ? get_columns_from_first_element : []
    end

    def can_get_columns_from_first_element?
      @array.first &&
      @array.first.respond_to?(:attributes) &&
      @array.first.attributes.respond_to?(:keys) &&
      @array.first.attributes.keys.is_a?(Array)
    end

    def get_columns_from_first_element
      @array.first.attributes.keys.sort_by {|sym| sym.to_s}.collect.to_a
    end

    def headers
      return  @headers if @headers
      @headers = @options[:headers] || columns
      raise ArgumentError, ":headers (#{@headers.inspect}) must be an array" unless @headers.is_a? Array
      @headers
    end

    def headers_should_be_included?
      @options[:headers] != false
    end

private

    def model_column_to_s(model_column)
      model_column.try(:to_fs) || model_column.try(:to_s)
    end

    def apply_format_to_row(row, format)
      row.default_format = format if format
    end

    def create_format(name)
      Spreadsheet::Format.new @options[name] if @options.has_key? name
    end

    def fill_row(row, column, model=nil)
      case column
      when String, Symbol
        row.push(model ? model.send(column) : column)
      when Hash
        column.each{|key, values| fill_row(row, values, model && model.send(key))}
      when Array
        column.each{|value| fill_row(row, value, model)}
      else
        raise ArgumentError, "column #{column} has an invalid class (#{ column.class })"
      end
    end

  end

end
