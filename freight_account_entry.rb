

require_relative './data_access_object.rb'


class FreightAccountEntry 
  include DataAccessObject 

  attr_accessor :txn_id, :member_id,  :company_information_id, :week_starting_date, :amount, :entry_type,   :user_date

  

  def initialize attributes
    fields =  [:txn_id, :member_id,  :company_information_id, :week_starting_date, :amount, :entry_type,   :user_date]
    populate  fields, attributes
  end


  def is_contribution?
    entry_type == 'contribution'
  end

  def is_correction?
    entry_type == 'correction'
  end

  # CLASS METHODS THAT OPERATE ON COLLECTIONS OF INSTANCES

  def self.get_account_current_entry_weeks(account_entries)
    current_entry_weeks = []
    weeks = account_entries.collect {|x| x.week_starting_date}.sort.uniq
    weeks.each do |week|
      current_entry_weeks << week if account_entries.select{|x| x.week_starting_date == week}.count.odd?
    end
    current_entry_weeks
  end


  def self.get_additions_for_account(emp_stat_data,account_entries)
    additions = []
    current_entry_weeks = self.get_account_current_entry_weeks(account_entries)
    emp_stat_data.each do |entry|
      additions << entry unless current_entry_weeks.include?(entry.week_starting_date)
    end
    additions
  end

  def self.get_deleted_weeks_for_account(emp_stat_data,account_entries)
    deletions = []
    self.get_account_current_entry_weeks(account_entries).each do |week|
      deletions << week unless emp_stat_data.select{|emp_stat_row| emp_stat_row.week_starting_date == week}.count > 0
    end
    deletions
  end

end
