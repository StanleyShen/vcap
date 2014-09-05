require 'rubygems'

require 'dataservice/postgres_ds'
require 'jobs/job'

module Jobs
  class Translations < Job
  end
end

class ::Jobs::Translations
  include DataService::PostgresSvc
  
  def initialize(options)
    options = options || {}
    @admin_key = options['translation_key'] ||  'admin.%'
    @def_lang = 'en'
  end

  def run    
    locales = supported_locales
    translations = translations(locales)

    send_json({'locales' => locales, 'translations' => translations}, true)
  end

  private

  def translations(locales)
    trans = {}

    sql = "select io_name, io_translations from io_translation where (io_deleted IS NULL or io_deleted='f') and io_name like $1"
    query_paras(sql, [@admin_key]) {|res|
      res.each{|row|
        values = row.values_at('io_name', 'io_translations')
        key = values[0]
        trans_vals = values[1]
        
        locales.each{|locale|
          translated = get_translated(trans_vals, locale)
          trans[locale] = trans[locale] || {}
          merge(trans[locale], to_hash(key, translated))
        }
      }
    }
    trans
  end
  
  def merge(hash_org, hash_other)
    hash_other.each { |k,v|
      org_item = hash_org[k]
      if org_item.nil?
        hash_org[k] = v
        next
      end
      
      if v.is_a?(Hash) && org_item.is_a?(Hash)
        hash_org[k] = merge(org_item, v)
      elsif !v.nil?
        hash_org[k] = v
      end
    }
    hash_org
  end
  
  def supported_locales
    locales = []
    sql = "select io_iso6391 from io_language where io_supported is not null and io_supported != 'f';"
    query(sql) {|res|
      res.each { |row|
        codes = row.values_at('io_iso6391')
        locales.concat(codes)
      }
    }
    make_default_locale_top(locales)

    locales
  end
  
  def make_default_locale_top(locales)
    locales = locales.uniq()
    if locales.include?(@def_lang)
      locales.delete(@def_lang)
      locales.insert(0, @def_lang)
    end
    locales
  end

  def get_translated(arr_str, locale)
    t_arr = parse_pg2d_array_str(arr_str)
    index = t_arr.index(locale)
    index.nil? ? nil : sanitize_string(t_arr[index+1])
  end
 
  def sanitize_string(str)
    str = str.slice(1, str.length-2) if str.is_a?(String) and str =~ /".+"/
    str
  end
  
  def to_hash(key, translated)
    keys = parse_key(key)
    current = translated
  
    keys.each { | k |
      hash = { k => current }
      current = hash
    }
    current
  end
  
  def parse_key(key)
    keys = key.split('.')
    keys.shift
    keys = keys.reverse
  end

  def parse_pg2d_array_str(data)
      arr = []
      is_inner = false
      current = []
      data.slice(1, data.length-2).each_char { |c|
        if(c=='{')
          #no_op
        elsif(c == '"')
          if is_inner
            is_inner = false
          else
            is_inner = true
          end
        elsif(c == '}' and !is_inner)
          if current.size > 0
            str = current.join()
            arr.push(str)
            current = []
          end
        elsif(c == ',' and !is_inner and current.size > 0)
          str = current.join()
          arr.push(str)
          current = []
        elsif(c == ',' and !is_inner and current.size == 0)
          #no_op
        else
          current.push(c)
        end
      }
      arr
  end
end
