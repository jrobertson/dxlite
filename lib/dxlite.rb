#!/usr/bin/env ruby

# file: dxlite.rb

require 'c32'
require 'json'
require 'recordx'
require 'rxfhelper'


class DxLite
  using ColouredText

  attr_accessor :summary
  attr_reader :records

  def initialize(s, filepath: nil, debug: false)

    @filepath, @debug = filepath, debug

    buffer, type = RXFHelper.read(s)
    puts 'type: ' + type.inspect if @debug
    puts 'buffer: ' + buffer.inspect if @debug
        
    case type
      
    when :file
      
      read buffer
      
    when :text
      
      @summary = {schema: s}
      @records = []
      
    when :url
      
      read buffer      
      
    end
    
    
    @schema = @summary[:schema]
    
    summary_attributes = {
      recordx_type: 'dynarex',
      default_key: @schema[/(?<=\()\w+/],
    }
    
    @summary.merge!(summary_attributes)

    summary = @summary[:schema][/(?<=\[)[^\]]+/]
    
    if summary then
      @summary.merge! summary.split(',').map {|x|[x.strip, nil] }.to_h
    end
    
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
        
        @records.select {|rec| find_record(rec[:body], value, x) }
        
      end

      define_singleton_method ('find_by_' + x).to_sym do |value|
        
        @records.find {|rec| find_record(rec[:body], value, x) }
        
      end

    end

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
    @records.delete found if found
  end
  
  def create(h, id: nil, custom_attributes: {created: Time.now})
    
    id ||= @records.map {|x| x[:id].to_i}.max.to_i + 1
    h2 = custom_attributes
    @records << {id: id.to_s, created: h2[:created], last_modified: nil, body: h}
  end
  
  def inspect()
    "#<DxLite:%s @debug=%s, @summary=%s, ...>" % [object_id, @debug, 
                                                  @summary.inspect]
  end
  
  # Parses 1 or more lines of text to create or update existing records.

  def parse(obj=nil)
    
    if obj.is_a? Array then
      
      unless schema() then
        cols = obj.first.keys.map {|c| c == 'id' ? 'uid' : c} 
        self.schema = "items/item(%s)" % cols.join(', ')
      end
        
      obj.each do |x|
        puts 'x: ' + x.inspect if @debug
        self.create x, id: nil
      end
      
      return self 
      
    end  
  end
  
  alias import parse

  def save(file=@filepath)
    File.write file, to_json()
  end
  
  alias to_a records
  
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
    r[:body].merge!(obj)
  end
  
  private
  
  def find_record(rec, value, x)
    value.is_a?(Regexp) ? rec[x.to_sym] =~ value : rec[x.to_sym] == value    
  end
  
  def read(buffer)
    
    h1 = JSON.parse(buffer, symbolize_names: true)
    puts 'h1:' + h1.inspect if @debug
    
    h = h1[h1.keys.first]
    
    @summary = h[:summary]
    @records = h[:records].map {|x| x[x.keys.first]}
    
  end
  
end
