#### Sam Choi 11/4/2013

class ParseConfig
  attr_accessor :hash_table, :config_struct

  def initialize()
    @hash_table = {}
    @config_struct ||= OpenStruct.new
  end

  def read_file(file_path, overrides)
    override = check_length_and_set_override(overrides)
    absolute_path = File.join(Dir.getwd, file_path)
    file = File.new(absolute_path, 'r')
    while line = file.gets
      if is_a_group?(line)
        group = remove_sqbrackets_from(line)
        @hash_table[group] = {}
      elsif is_a_new_line_or_comment?(line)
        next
      else
        setting_value_pair = remove_comments_and_split(line)
        setting = remove_space_and_quotes_from(setting_value_pair[0])
        value = remove_space_and_quotes_from(setting_value_pair[1])
        if value_is_int?(value)
          if enabled_is_in?(setting)
            parse_enabled(group, setting, value.to_i)
          else
            assign(group, setting, value.to_i)
          end
        elsif enabled_is_in?(setting)
          parse_enabled(group, setting, value)
        elsif value_is_array?(value)
          assign(group, setting, value.split(','))
        elsif env_is_in?(setting)
          if override == nil
            next
          elsif single_override_equals_environment_of(setting, override, overrides)
            assign(group, remove_env_from(setting), value)
          elsif not override.include? environment_of(setting)
            next
          else
            assign(group, remove_env_from(setting), value)
          end
        elsif not env_is_in?(setting)
          if value_is_present_within?(group,setting)
            next
          else
            assign(group, setting, value)
          end
        else
          assign(group, setting, value)
        end
      end
    end
  end

  def load_config(file_path, overrides = [])
    begin
      read_file(file_path, overrides)
      @hash_table.each do |group, settings_and_values|
        set_and_val_struct = OpenStruct.new(settings_and_values)
        @hash_table[group] = set_and_val_struct
      end
      @config_struct = OpenStruct.new(@hash_table)
    rescue Exception => err
      error_message = 'conf file not well-formed'
      Rails.logger.info error_message
  end

  protected
  def method_missing
    return nil
  end

  def check_length_and_set_override(overrides)
    if overrides.length == 1
      override = overrides.first.to_s
    elsif overrides.length == 0
      override = nil
    else
      override = overrides.map &:to_s
    end
  end

  def single_override_equals_environment_of(setting, override, overrides)
    overrides.length == 1 and override == environment_of(setting)
  end

  def remove_space_and_quotes_from(expression)
    expression.squish.gsub(/"/,"")
  end

  def remove_sqbrackets_from(line)
    line.gsub(/\]\s/,"").gsub(/\[/, "")
  end

  def env_regex
    /<[a-zA-Z]*>/
  end

  def remove_env_from(setting)
    setting.gsub(env_regex, '')
  end

  def remove_comments_and_split(line)
    remove_comments = line.gsub(/;[a-zA-Z]/,"")
    setting_value_pair = remove_comments.split('=')
  end

  def is_a_group?(line)
    line[0] == '['
  end

  def is_a_new_line_or_comment?(line)
    (line.length == 1 and line.match(/\n/)) or line[0] == ';'
  end

  def value_is_int?(value)
    value.match(/\d/)
  end

  def value_is_array?(value)
    value.match(/[a-z],[a-z]/)
  end

  def env_is_in?(setting)
    setting.match(env_regex)
  end

  def environment_of(setting)
    setting[env_regex].gsub(/</,'').gsub(/>/,'')
  end

  def value_is_present_within?(group,setting)
    not @hash_table[group][setting].nil?
  end

  def assign(group, setting, value)
    @hash_table[group][setting] = value
  end

  def enabled_is_in?(setting)
    setting.include? 'enabled'
  end

  def parse_enabled(group, setting, value)
    if value == 'no' || value == 'false' || value == 0
      assign(group, setting, false)
    elsif value == 'yes' || value == 'true' || value == 1
      assign(group, setting, true)
    else
      assign(group, setting, nil)
    end
  end
end
