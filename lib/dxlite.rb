#!/usr/bin/env ruby

# file: dxlite.rb

require 'c32'
require 'json'
require 'recordx'
require 'rxfhelper'


class DxLite
  using ColouredText

  attr_accessor :summary, :filepath, :schema
  attr_reader :records

  def initialize(s=nil, autosave: false, debug: false)

    @autosave, @debug = autosave, debug

    return unless s
    buffer, type = RXFHelper.read(s)

    @filepath = s if type == :file or type == :dfs

    puts 'type: ' + type.inspect if @debug
    puts 'buffer: ' + buffer.inspect if @debug

    @records = []

    case type

    when :file

      read buffer

    when :text

      @summary = {schema: s}


    when :url

      read buffer

    end

    puts '@summary: ' + @summary.inspect if @debug
    @schema = @summary[:schema]

    summary_attributes = {
      recordx_type: 'dynarex',
      default_key: @schema[/(?<=\()\w+/]
    }

    puts 'before merge' if @debug
    @summary.merge!(summary_attributes)

    summary = @summary[:schema][/(?<=\[)[^\]]+/]

    if summary then

      summary.split(/ *, */).each do |x|
        @summary[x] = nil unless @summary[x]
      end

    end

    make_methods()

  end

  def all()

    @records.map do |h|

      puts 'h: ' + h.inspect if @debug
      RecordX.new(h[:body], self, h[:id], h[:created],
                  h[:last_modified])
    end

  end

  def delete(id)
    found = @records.find {|x| x[:id] == id}

    if found then
      @records.delete found
      save() if @autosave
    end

  end

  def create(rawh, id: nil, custom_attributes: {created: Time.now})

    if @debug then
      puts 'create:: rawh: ' + rawh.inspect
      puts 'custom_attributes: ' + custom_attributes.inspect
    end

    key = @summary[:default_key]

    if key then

      r = records.find {|x| x[:body][key.to_sym] == rawh[key.to_sym]}
      if r then
        r[:last_modified] = Time.now.to_s
        return false
      end

    end

    if id.nil? then

      puts '@records: ' + @records.inspect if @debug

      if @records then
        id = @records.map {|x| x[:id].to_i}.max.to_i + 1
      else
        @records = []
        id = 1
      end

    end

    h2 = custom_attributes

    fields = rawh.keys
    puts 'fields: ' + fields.inspect if @debug

    h3 = fields.map {|x| [x.to_sym, nil] }.to_h.merge(rawh)
    h = {id: id.to_s, created: h2[:created], last_modified: nil, body: h3}
    @records << h

    save() if @autosave

    RecordX.new(h[:body], self, h[:id], h[:created], h[:last_modified])

  end

  def fields()
    @fields
  end

  def inspect()
    "#<DxLite:%s @debug=%s, @summary=%s, ...>" % [object_id, @debug,
                                                  @summary.inspect]
  end

  # Parses 1 or more lines of text to create or update existing records.

  def parse(obj=nil)

    if obj.is_a? Array then

      unless schema() then
        puts 'obj.first: ' + obj.first.inspect if @debug
        cols = obj.first.keys.map {|c| c == 'id' ? 'uid' : c}
        puts 'after cols' if @debug
        self.schema = "items/item(%s)" % cols.join(', ')
      end

      obj.each do |x|
        #puts 'x: ' + x.inspect if @debug
        self.create x, id: nil
      end

      return self

    end
  end

  alias import parse

  def parse_xml(buffer)

    doc = Rexle.new(buffer)

    asummary = doc.root.xpath('summary/*').map do |node|
      puts 'node: '  + node.xml.inspect if @debug
      [node.name, node.text.to_s]
    end

    summary = Hash[asummary]
    summary[:schema] = summary['schema']
    %w(recordx_type format_mask schema).each {|x| summary.delete x}

    schema = summary[:schema]
    puts 'schema: ' + schema.inspect if @debug

    @fields = schema[/\(([^\)]+)/,1].split(/ *, +/)
    puts 'fields: ' + @fields.inspect if @debug

    @summary = summary

    a = doc.root.xpath('records/*').each do |node|

      h = Hash[@fields.map {|field| [field.to_sym, node.text(field).to_s] }]
      self.create h, id: nil, custom_attributes: node.attributes

    end

  end

  def save(file=@filepath)

    return unless file
    @filepath = file

    s = File.extname(file) == '.json' ? to_json() : to_xml()
    File.write file, s
  end

  def to_a()
    @records.map {|x| x[:body]}
  end

  def to_h()

    root_name = schema()[/^\w+/]
    record_name = schema()[/(?<=\/)[^\(]+/]

    h = {
      root_name.to_sym =>
      {
        summary: @summary,
        records: @records.map {|h| {record_name.to_sym => h} }
      }
    }

  end

  def to_json(pretty: true)
    pretty ? JSON.pretty_generate(to_h()) : to_h()
  end

  def to_xml()

    root_name = schema()[/^\w+/]
    record_name = schema()[/(?<=\/)[^\(]+/]

    a = RexleBuilder.build  do |xml|

      xml.send(root_name.to_sym) do
        xml.summary({}, @summary)
        xml.records do

          all().each do |x|

            h = {id: x.id, created: x.created, last_modified: x.last_modified}
            puts 'x.to_h: ' + x.to_h.inspect if @debug
            xml.send(record_name.to_sym, h, x.to_h)

          end

        end
      end
    end

    Rexle.new(a).xml pretty: true


  end

  # Updates a record from an id and a hash containing field name and field value.
  #  dynarex.update 4, name: Jeff, age: 38

  def update(id, obj)

    if @debug then
      puts 'inside update'.info
      puts ('id: ' + id.inspect).debug
      puts ('obj.class: '  + obj.class.inspect).debug
    end

    r = @records.find {|x| x[:id] == id}

    if r then

      r[:body].merge!(obj)
      save() if @autosave

    end

  end

  private

  def find_record(rec, value, x)
    r = value.is_a?(Regexp) ? rec[x.to_sym] =~ value : rec[x.to_sym] == value
  end

  def make_methods()

    # for each summary item create get and set methods

    @summary.each do |key, value|

      define_singleton_method(key) { @summary[key] }

      define_singleton_method (key.to_s + '=').to_sym do |value|
        @summary[key] = value
      end

    end

    @fields = @summary[:schema][/(?<=\()[^\)]+/].split(',').map(&:strip)

    @fields.each do |x|

      define_singleton_method ('find_all_by_' + x).to_sym do |value|

        a = @records.select {|rec| find_record(rec[:body], value, x) }

        a.map do |h|
          RecordX.new(h[:body], self, h[:id], h[:created], h[:last_modified])
        end

      end

      define_singleton_method ('find_by_' + x).to_sym do |value|

        h = @records.find {|rec| find_record(rec[:body], value, x) }
        return nil unless h

        RecordX.new(h[:body], self, h[:id], h[:created], h[:last_modified])

      end

    end

  end

  def read(buffer)

    if buffer[0] == '<' then

      parse_xml buffer

    else

      h1 = JSON.parse(buffer, symbolize_names: true)
      #puts 'h1:' + h1.inspect if @debug

      h = h1[h1.keys.first]

      @summary = {}

      h[:summary].each do |key, value|

        if %i(recordx_type format_mask schema).include? key then
          @summary[key] = value
        else
          @summary[key.to_s] = value
        end

      end

      @records = h[:records].map {|x| x[x.keys.first]}

    end

  end

end
