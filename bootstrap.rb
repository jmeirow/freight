require_relative './allocation_periods.rb'

include AllocationPeriods


ALLOCATION_PERIODS.each do |range|
  puts "#{range.first} (#{range.first.wday}) - #{range.last} (#{range.last.wday})"
end

