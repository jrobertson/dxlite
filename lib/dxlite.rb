#!/usr/bin/env ruby

# file: dxlite.rb

require 'json'
require 'recordx'
require 'rxfhelper'

class DxLite

  attr_accessor :summary
  attr_reader :records

  def initialize(s, debug: false)

    @debug = debug

    buffer, type = RXFHelper.read(s)
    puts 'type: ' + type.inspect if @debug
    h = JSON.parse(buffer, symbolize_names: true)

    @filepath = s if type == :file

    @summary = h[:summary]
    @records = h[:records]
    @fields = @summary[:schema][/(?<=\()[^\)]+/].split(',').map(&:strip)

    @fields.each do |x|

      define_singleton_method ('find_all_by_' + x).to_sym do |value|
        @records.select {|rec| rec[x.to_sym] == value }
      end

      define_singleton_method ('find_by_' + x).to_sym do |value|
        @records.find {|rec| rec[x.to_sym] == value }
      end

    end

  end  

  def all()

    @records.map do |h|
      RecordX.new(h, self, h[:id], h[:created], h[:last_modified])
    end

  end  
  
  def create(h)
    @records << h
  end

  def save(file=@filepath)
    File.write file, @records.to_json
  end
  
end
