require 'sidekiq'
require 'mysql2'
require 'mysql2-cs-bind'

class PostConditionWorker
  include Sidekiq::Worker

  def perform(jia_isu_uuid, json_params)
		db_transaction do
			count = db.xquery('SELECT COUNT(*) AS `cnt` FROM `isu` WHERE `jia_isu_uuid` = ?', jia_isu_uuid).first
			halt_error 404, 'not found: isu' if count.fetch(:cnt).zero?

			values = json_params.map do |cond|
				halt_error 400, 'bad request body' unless valid_condition_format?(cond.fetch('condition'))
				timestamp = Time.at(cond.fetch('timestamp'))
				level = calculate_condition_level(cond.fetch('condition'))
				[jia_isu_uuid, timestamp, cond.fetch('is_sitting'), cond.fetch('condition'), cond.fetch('message'), level]
			end

			db.xquery(
				"INSERT INTO `isu_condition` (`jia_isu_uuid`, `timestamp`, `is_sitting`, `condition`, `message`, `level`) VALUES #{(["(?, ?, ?, ?, ?, ?)"] * values.length).join(',')}",
				values.flatten
			)
		end
	rescue Exception => e
		puts e.message
		puts e.backtrace
  end

	private

	def db
		Thread.current[:db] ||= Mysql2::Client.new(
															host: '127.0.0.1',
															port: '3306',
															username: 'isucon',
															database: 'isucondition',
															password: 'isucon',
															charset: 'utf8mb4',
															database_timezone: :local,
															cast_booleans: true,
															symbolize_keys: true,
															reconnect: true,
														)
	end

	def db_transaction(&block)
		db.query('BEGIN')
		done = false
		retval = block.call
		db.query('COMMIT')
		done = true
		return retval
	ensure
		db.query('ROLLBACK') unless done
	end

	CONDITION_LEVEL_INFO = 'info'
	CONDITION_LEVEL_WARNING = 'warning'
	CONDITION_LEVEL_CRITICAL = 'critical'

	# ISUのコンディションの文字列からコンディションレベルを計算
	def calculate_condition_level(condition)
		idx = -1
		warn_count = 0
		while idx
			idx = condition.index('=true', idx+1)
			warn_count += 1 if idx
		end

		case warn_count
		when 0
			CONDITION_LEVEL_INFO
		when 1, 2
			CONDITION_LEVEL_WARNING
		when 3
			CONDITION_LEVEL_CRITICAL
		else
			raise "unexpected warn count"
		end
	end

	# ISUのコンディションの文字列がcsv形式になっているか検証
	def valid_condition_format?(condition_str)
		keys = %w(is_dirty= is_overweight= is_broken=)
		value_true = 'true'
		value_false = 'false'

		idx_cond_str = 0
		keys.each_with_index do |key, idx_keys|
			return false unless condition_str[idx_cond_str..-1].start_with?(key)
			idx_cond_str += key.size
			case
			when condition_str[idx_cond_str..-1].start_with?(value_true)
				idx_cond_str += value_true.size
			when condition_str[idx_cond_str..-1].start_with?(value_false)
				idx_cond_str += value_false.size
			else
				return false
			end

			if idx_keys < (keys.size-1)
				return false unless condition_str[idx_cond_str] == ?,
				idx_cond_str += 1
			end
		end

		idx_cond_str == condition_str.size
	end

	def get_env(key, default)
		val = ENV.fetch(key, '')
		return val unless val.empty?
		default
	end
end