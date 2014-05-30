require_relative './data_access_object.rb'
require_relative './money.rb'
require_relative './allocation_periods.rb'

require 'pry'




class FreightAccountEntry 
  include DataAccessObject 
  include AllocationPeriods

  attr_accessor :txn_id, :member_id,  :company_information_id, :billing_tier, :week_starting_date, :amount, :entry_type,   :user_date, :plan_code, :is_reversal, :note 

  def initialize attributes
    fields =  [:txn_id, :member_id,  :company_information_id, :billing_tier, :week_starting_date, :amount, :entry_type,   :user_date, :plan_code, :is_reversal, :note ]
    populate  fields, attributes
  end


  def is_contribution?
    entry_type == 'contribution'
  end

  def is_reversal?
    return true if  (is_reversal && (is_reversal == 'Y'))
    false
  end

  def is_coverage?
    entry_type == 'coverage'
  end

  def self.contribution
    'contribution'
  end

 

  def self.coverage
    'coverage'
  end


  # CLASS METHODS THAT OPERATE ON COLLECTIONS OF INSTANCES

  def self.get_account_current_entry_weeks(account_entries)
    current_entry_weeks = []
    weeks = account_entries.collect {|x| x.week_starting_date}.sort.uniq
    weeks.each do |week|
      current_entry_weeks << week if (account_entries.select{|x| ((x.week_starting_date == week)  && (x.is_contribution?)) }.count.odd?)
    end
    current_entry_weeks
  end


  def self.get_employer_id(account_entries)

    last_week = self.get_account_current_entry_weeks(account_entries).last



    result = account_entries.find{|x|( x.week_starting_date == last_week) && (x.is_contribution?) && (x.is_reversal?  == false) } 



    result.company_information_id
  end


  def self.get_account_current_coverage_entries(account_entries)
    current_fb_week_starting_dates = []
    current_fb_entries = []

    weeks = account_entries.collect {|x| x.week_starting_date}.sort.uniq
    weeks.each do |week|
      current_fb_week_starting_dates << week if account_entries.select{|x| (x.week_starting_date == week  && (x.is_coverage?)) }.count.odd?
    end

    current_fb_week_starting_dates.each do |week_starting_date|  
      current_fb_entries << account_entries.select{|x| x.week_starting_date == week_starting_date }.last 
    end

    current_fb_entries
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

  def self.balance account_entries
    sum = Money.new(0.00)
    account_entries.each do |entry| 
      sum = sum + entry.amount if( current_allocation_period.cover? entry.week_starting_date) 
    end
    sum
  end

end
