require_relative './allocation_periods.rb'
require 'pp'


include AllocationPeriods

members = FreightAccumulation::Repository.get_freight_members



members.each do |member_id|
  journal = get_journal_data
end
