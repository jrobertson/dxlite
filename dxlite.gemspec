Gem::Specification.new do |s|
  s.name = 'dxlite'
  s.version = '0.6.4'
  s.summary = 'Handles Dynarex documents (in JSON format) faster and ' + 
      'with less overheads.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/dxlite.rb']
  s.add_runtime_dependency('recordx', '~> 0.6', '>=0.6.0')
  s.signing_key = '../privatekeys/dxlite.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/dxlite'
end
