require_relative './date.rb'


module AllocationPeriods


    FREIGHT_ACCUM_START_DATE ||= Date.new(2014,3,30) 

    ALLOCATION_PERIODS =  
    [
      Date.new(2012,4, 1)..Date.new(2015,3,28),
      Date.new(2015,3,29)..Date.new(2018,3,31),
      Date.new(2018,4, 1)..Date.new(2021,3,27),
      Date.new(2021,3, 28)..Date.new(2024,3,30)
    ]


  def first_allocation_period
     Date.new(2012,4, 1)..Date.new(2015,3,28)
  end
  
  def half_pay_date_range
    if ALLOCATION_PERIODS.first.cover? Date.today
      FREIGHT_ACCUM_START_DATE..ALLOCATION_PERIODS.first.last 
    else
      ALLOCATION_PERIODS.select{|x| x.cover?(Date.today)}.first
    end
  end

  def current_allocation_period
    ALLOCATION_PERIODS.select{|x| x.cover? Date.today }.first
  end

  def get_prior_allocation_periods
    ALLOCATION_PERIODS.select{|x| x.last < Date.today  }
  end

  def get_prior_dates
    min_date = Date.new(2012,4,1)
    max_date = Date.new(2012,4,1)
    get_prior_allocation_periods.each do |range|
      min_date = range.first if range.first <= min_date 
      max_date = range.last if range.last >= max_date 
    end
    min_date..max_date
  end

end
