# frozen_string_literal: true

require 'English'
require 'digest/md5'
require 'json'
require 'openssl'
require 'stringio'
require 'tmpdir'
require 'zlib'

hostname           = 'repo.lichproject.org'
port               = 7157
ca_cert            = OpenSSL::X509::Certificate.new("-----BEGIN CERTIFICATE-----\nMIIDoDCCAoigAwIBAgIUYwhIyTlqWaEd5mYGXoQQoC+ndKcwDQYJKoZIhvcNAQEL\nBQAwYTELMAkGA1UEBhMCVVMxETAPBgNVBAgMCElsbGlub2lzMRIwEAYDVQQKDAlN\nYXR0IExvd2UxDzANBgNVBAMMBlJvb3RDQTEaMBgGCSqGSIb3DQEJARYLbWF0dEBp\nbzQudXMwHhcNMjQwNjA1MTM1NzUxWhcNNDQwNTMxMTM1NzUxWjBhMQswCQYDVQQG\nEwJVUzERMA8GA1UECAwISWxsaW5vaXMxEjAQBgNVBAoMCU1hdHQgTG93ZTEPMA0G\nA1UEAwwGUm9vdENBMRowGAYJKoZIhvcNAQkBFgttYXR0QGlvNC51czCCASIwDQYJ\nKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJwhGfQgwI1h4vlqAqaR152AlewjJMlL\nyoqtjoS9Cyri23SY7c6v0rwhoOXuoV1D2d9InmmE2CgLL3Bn2sNa/kWFjkyedUca\nvd8JrtGQzEkVH83CIPiKFCWLE5SXLvqCVx7Jz/pBBL1s173p69kOy0REYAV/OAdj\nioCXK6tHqYG70xvLIJGiTrExGeOttMw2S+86y4bSxj2i35IscaBTepPv7BWH8JtZ\nyN4Xv9DBr/99sWSarlzUW6+FTcNqdJLP5W5a508VLJnevmlisswlazKiYNriCQvZ\nsnmPJrYFYMxe9JIKl1CA8MiUKUx8AUt39KzxkgZrq40VxIrpdxrnUKUCAwEAAaNQ\nME4wHQYDVR0OBBYEFJxuCVGIbPP3LO6GAHAViOCKZ4HIMB8GA1UdIwQYMBaAFJxu\nCVGIbPP3LO6GAHAViOCKZ4HIMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQELBQAD\nggEBAGKn0vYx9Ta5+/X1WRUuADuie6JuNMHUxzYtxwEba/m5lA4nE5f2yoO6Y/Y3\nLZDX2Y9kWt+7pGQ2SKOT79gNcnOSc3SGYWkX48J6C1hihhjD3AfD0hb1mgvlJuij\nzNnZ7vczOF8AcvBeu8ww5eIrkN6TTshjICg71/deVo9HvjhiCGK0XvL+WL6EQwLe\n6/nVVFrPfd0sRZZ5OTJR5nM1kA71oChUw9mHCyrAc3zYyW37k+p8ADRFfON8th8M\n1Blel1SpgqlQ22WpYoHbUCSjGt6JKC/HrSHdKBezTuRahOSfqwncAE77Dz4FJaQ5\nWD2mk3SZbB2ytAHUDEy3xr697EI=\n-----END CERTIFICATE-----")
client_version     = '2.38'
mapdb_reloaded     = false
cmd                = []
cmd_author         = nil
cmd_password       = nil
cmd_tags           = nil
cmd_show_tags      = nil
cmd_sort           = nil
cmd_reverse        = nil
cmd_limit          = nil
cmd_force          = nil
cmd_name           = nil
cmd_game           = nil
cmd_age            = nil
cmd_size           = nil
cmd_downloads      = nil
cmd_rating         = nil
cmd_version        = nil
no_more_options    = nil
cmd_show_tags      = nil
cmd_hide_age       = nil
cmd_hide_size      = nil
cmd_hide_author    = nil
cmd_hide_downloads = nil
cmd_hide_rating    = nil

# MOCKS
LICH_VERSION = '6.0.0'

class MockXMLData
  attr_accessor :game

  def initialize(game)
    @game = game
  end
end


def echo(msg)
  puts(msg)
end

Settings = {}

# mirror setup
temp_dir = Dir.tmpdir
work_dir = ENV['GITHUB_WORKSPACE']


cmd_force = true

game_code = ENV['GAMECODE']

$MIRROR_DR = ENV.fetch('MIRROR_DR', nil)

game_code = 'GS'
XMLData = MockXMLData.new(game_code)

map_data_dir = "#{work_dir}/map_files"
map_images_dir = "#{work_dir}/map_files"
map_file = File.join(map_data_dir, 'mapdb.json')

map_updated_at_file = File.join(map_data_dir, 'updated_at')

echoput = proc { |msg|
  echo msg
}

connect = proc {
  begin
    if ca_cert.not_before > Time.now
      echoput.call("Cert is not valid yet")
      verify_mode = OpenSSL::SSL::VERIFY_NONE
    elsif ca_cert.not_after < Time.now
      echoput.call("Cert is expired")
      verify_mode = OpenSSL::SSL::VERIFY_NONE
    else
      verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    cert_store = OpenSSL::X509::Store.new
    cert_store.add_cert(ca_cert)
    ssl_context             = OpenSSL::SSL::SSLContext.new
    ssl_context.options     = (OpenSSL::SSL::OP_NO_SSLv2 + OpenSSL::SSL::OP_NO_SSLv3)
    ssl_context.cert_store  = cert_store
    ssl_context.verify_mode = if OpenSSL::SSL::VERIFY_PEER == OpenSSL::SSL::VERIFY_NONE
                                # the plat_updater script redefines OpenSSL::SSL::VERIFY_PEER, disabling it for everyone
                                1 # probably right
                              else
                                verify_mode
                              end
    socket                  = TCPSocket.new(hostname, port)
    ssl_socket              = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
    ssl_socket.connect
    if (ssl_socket.peer_cert.subject.to_a.find do |n|
          n[0] == 'CN'
        end [1] != 'lichproject.org') && (ssl_socket.peer_cert.subject.to_a.find do |n|
                                            n[0] == 'CN'
                                          end [1] != 'Lich Repository')
      if cmd_force
        echo 'warning: server certificate hostname mismatch'
      else
        echo 'error: server certificate hostname mismatch'
        begin
          ssl_socket.close
        rescue StandardError
          nil
        end
        begin
          socket.close
        rescue StandardError
          nil
        end
        exit
      end
    end
    def ssl_socket.geth
      hash = {}
      gets.scan(/[^\t]+\t[^\t]+(?:\t|\n)/).each do |s|
        s = s.chomp.split("\t")
        hash[s[0].downcase] = s[1]
      end
      hash
    end

    def ssl_socket.puth(h)
      puts h.to_a.flatten.join("\t")
    end
  rescue StandardError
    echo "error connecting to server: #{$ERROR_INFO}"
    begin
      ssl_socket.close
    rescue StandardError
      nil
    end
    begin
      socket.close
    rescue StandardError
      nil
    end
  end
  [ssl_socket, socket]
}

download_mapdb = proc { |xmldata|
  if xmldata
    XMLData = xmldata unless defined?(XMLData)
  elsif game_code
    XMLData = MockXMLData.new(game_code) unless defined?(XMLData)
  else
    XMLData = MockXMLData.new('GS') unless defined?(XMLData)
  end
 
  failed = true
  downloaded = false

  game = case XMLData.game
         when /^GS/i
           if XMLData.game =~ /^GSF$|^GSPlat$/i
             XMLData.game.downcase
           else
             'gsiv'
           end
         when /^DR/i
           if XMLData.game =~ /^DRF$|^DRX$/i
             XMLData.game.downcase
           else
             'dr'
           end
         else
           XMLData.game.downcase
         end
  request = { 'action' => 'download-mapdb', 'game' => game, 'supported compressions' => 'gzip',
              'client' => client_version }
  request['current-md5sum'] = if File.exist?(map_file)
                                Digest::MD5.file(map_file).to_s
                              else
                                'x'
                              end
  begin
    newfilename = map_file
    ssl_socket, socket = connect.call
    ssl_socket.puth(request)
    response = ssl_socket.geth
    echo "warning: server says: #{response['warning']}" if response['warning']
    if response['error']
      if response['error'] == 'already up-to-date'
        if response['timestamp'] && response['uploaded by']
          echo "map database is up-to-date; last updated by #{response['uploaded by']} at #{Time.at(response['timestamp'].to_i)}"
        else
          echo 'map database is up-to-date'
        end
        failed = false
      else
        echo "error: server says: #{response['error']}"
      end
    elsif response['compression'] && (response['compression'] != 'gzip')
      echo "error: unsupported compression method: #{response['compression']}"
    else
      response['size'] = response['size'].to_i
      tempfilename = "#{temp_dir}/#{rand(100_000_000)}.repo"
      if response['timestamp'] && response['uploaded by']
        echo "downloading map database... (uploaded by #{response['uploaded by']} at #{Time.at(response['timestamp'].to_i)})"
      else
        echo 'downloading map database...'
      end
      File.open(tempfilename, 'wb') do |f|
        (response['size'] / 1_000_000).times { f.write(ssl_socket.read(1_000_000)) }
        f.write(ssl_socket.read(response['size'] % 1_000_000)) unless (response['size'] % 1_000_000).zero?
      end
      if response['compression'] == 'gzip'
        ungzipname = "#{temp_dir}/#{rand(100_000_000)}"
        ungzipname = File.join(temp_dir, 'temp_map.repo')
        File.open(ungzipname, 'wb') do |f|
          Zlib::GzipReader.open(tempfilename) do |f_gz|
            while data = f_gz.read(1_000_000)
              f.write(data)
            end
            data = nil
          end
        end
        begin
          File.rename(ungzipname, tempfilename)
        rescue StandardError
          if $ERROR_INFO.to_s =~ /Invalid cross-device link/
            File.open(ungzipname, 'rb') { |r| File.open(tempfilename, 'wb') { |w| w.write(r.read) } }
            File.delete(ungzipname)
          else
            raise $ERROR_INFO
          end
        end
      end
      md5sum_mismatch = (Digest::MD5.file(tempfilename).to_s != response['md5sum'])
      if md5sum_mismatch && !cmd_force
        echo 'error: md5sum mismatch: file likely corrupted in transit'
        File.delete(tempfilename)
      else
        echo 'warning: md5sum mismatch: file likely corrupted in transit' if md5sum_mismatch
        begin
          File.rename(tempfilename, newfilename)
        rescue StandardError
          if $ERROR_INFO.to_s =~ /Invalid cross-device link/
            File.open(tempfilename, 'rb') { |r| File.open(newfilename, 'wb') { |w| w.write(r.read) } }
            File.delete(tempfilename)
          else
            raise $ERROR_INFO
          end
        end
        failed = false
        downloaded = true
      end
      updated_timestamp = Time.at(response['timestamp'].to_i)
      File.open(map_updated_at_file, 'w') do |file|
        file.write("Last updater: #{response['uploaded by']}\n")
        file.write(updated_timestamp)
      end
    end
  ensure
    begin
      ssl_socket.close
    rescue StandardError
      nil
    end
    begin
      socket.close
    rescue StandardError
      nil
    end
  end
  unless failed
    ### commented out but leaving in case we add mirroring image files later
    map_json = nil
    File.open(newfilename) { |f|
      map_json = JSON.parse(f.read)
    }
    map_json_images = map_json.map { |r| r['image'] }.uniq
    map_json_images.delete(nil)
    existing_maps = Dir["#{map_images_dir}/*"].map { |f| f.split("/").last }
    image_filenames = map_json_images - existing_maps
    image_filenames = []
    unless image_filenames.empty?
      echo 'downloading missing map images...'
      begin
        ssl_socket, socket = connect.call
        ssl_socket.puth('action' => 'download-mapdb-images', 'files' => image_filenames.join('/'),
                        'client' => client_version)
        loop do
          response = ssl_socket.geth
          echo "warning: server says: #{response['warning']}" if response['warning']
          if response['error']
            echo "error: server says: #{response['error']}"
            break
          elsif response['success']
            break
          elsif !(response['file']) || !(response['size']) || !(response['md5sum'])
            echo "error: unrecognized response from server: #{response.inspect}"
            break
          end
          response['size'] = response['size'].to_i
          tempfilename = "#{temp_dir}/#{rand(100_000_000)}.repo"
          echo "downloading #{response['file']}..."
          File.open(tempfilename, 'wb') do |f|
            (response['size'] / 1_000_000).times { f.write(ssl_socket.read(1_000_000)) }
            f.write(ssl_socket.read(response['size'] % 1_000_000)) unless (response['size'] % 1_000_000).zero?
          end
          md5sum_mismatch = (Digest::MD5.file(tempfilename).to_s != response['md5sum'])
          if md5sum_mismatch && !cmd_force
            echo 'error: md5sum mismatch: file likely corrupted in transit'
            File.delete(tempfilename)
          else
            echo 'warning: md5sum mismatch: file likely corrupted in transit' if md5sum_mismatch
            begin
              File.rename(tempfilename, "#{map_images_dir}/#{response['file']}")
            rescue StandardError
              if $ERROR_INFO.to_s =~ /Invalid cross-device link/
                File.open(tempfilename, 'rb') do |r|
                  File.open("#{map_images_dir}/#{response['file']}", 'wb') do |w|
                    w.write(r.read)
                  end
                end
                File.delete(tempfilename)
              else
                raise $ERROR_INFO
              end
            end
          end
        end
      ensure
        begin
          ssl_socket.close
        rescue StandardError
          nil
        end
        begin
          socket.close
        rescue StandardError
          nil
        end
      end
    end
    echo 'done downloading map'
    true
  end
}

i = 0
3.times do
  res = download_mapdb.call
  break if res
rescue StandardError => e
  puts e.inspect
  i += 1
  echo "Error downloading map. Attempt #{i} / 3"
end
