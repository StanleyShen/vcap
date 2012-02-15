#!/usr/bin/env ruby
# clean the staged droplets using the app_id and timestamp of the staging
# that are written inside the startup script:
#commented out just like this:
#TS=1327905632
#APP_ID=1

#for every app_id only keep the most recent staged droplet.
staged_app_id_by_droplet_file={}
staged_app_id_by_staging_ts={}
staged_droplets_path='/var/vcap/shared/droplets'
delete_non_staged_droplets=true

Dir.chdir(Dir.new(staged_droplets_path)) do
  File.delete("startup") if File.exists? "startup"
  Dir.new(Dir.pwd).entries.each do |filename|
    next if File.directory?(filename)
    p "looking at #{filename}"
    mime=`file -i #{filename}`.strip
    unless mime.empty?
      if mime =~ /zip/
        if mime =~ /gzip/
          File.delete("startup") if File.exists? "startup"
          `tar -xzf #{filename} startup`
          if File.exists? "startup"
            ts_line=`grep \#TS= startup`.strip
            app_id_line=`grep \#APP_ID= startup`.strip
            unless ts_line.empty? or app_id_line.empty?
              app_id=app_id_line.split('=')[1]
              ts=ts_line.split('=')[1].to_i
              puts "Droplet #{filename} for App-ID #{app_id} staged at #{Time.at(ts)}"
              prev_ts=staged_app_id_by_staging_ts[app_id]
              puts "  Another staged droplet for the same app was staged at #{Time.at(prev_ts)}" if prev_ts
              if prev_ts.to_i > 0
                prev_droplet=staged_app_id_by_droplet_file[app_id]
                if ts > prev_ts
                  puts "App-ID #{app_id}'s droplet #{prev_droplet} is less recent than #{filename}; deleting it"
                  File.delete(prev_droplet) if File.exists?(prev_droplet)
                  staged_app_id_by_staging_ts[app_id]=ts
                  staged_app_id_by_droplet_file=filename
                else
                  puts "App-Id #{app_id}'s droplet #{filename} is less recent than #{prev_droplet}; deleting it"
                  File.delete(filename)
                end
              else
                staged_app_id_by_staging_ts[app_id]=ts
                staged_app_id_by_droplet_file[app_id]=filename
              end
            else
              puts "No TS or APP_ID in the startup script of #{filename}"
            end
            File.delete("startup")
          else
            puts "No startup file in this staged droplet? #{filename}"
          end
        else
          puts "deleting #{filename} because it is a zip" if delete_non_staged_droplets
          File.delete(filename) if delete_non_staged_droplets
        end
      end
      
    end
  end
  
end
