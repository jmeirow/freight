require 'date'

class Date


  # def today_is(*args)
  #   days = {}
  #   days[:sunday] = 0
  #   days[:monday] = 1
  #   days[:tuesday] =

  def mctwf_sunday_of_week
    return self if self.wday == 0
    self - self.wday
  end


  def mctwf_next_months_weeks
    dt = mctwf_last_saturday_of_month + 1
    first_saturday = dt.mctwf_saturday_of_week

    week_starting_dates = []
    week_starting_dates << dt 
    (0..6).each do |idx|
      dt += 7
      week_starting_dates << dt   if dt.month == first_saturday.month
    end
    week_starting_dates
  end


  
  def mctwf_saturday_of_week
    return self if self.wday == 6
    self + (6 - self.wday)
  end  


  

  def mctwf_first_of_calendar_month 
    Date.new(self.year,self.month,1)
  end





  def mctwf_last_saturday_of_month
    (0..6).collect{ |x| self.mctwf_saturday_of_week+(7*x)}.select{ |x| x.month == self.mctwf_saturday_of_week.month}.last 
  end 




  def mctwf_fund_start_of_month
    mctwf_first_saturday_of_month - 6
  end




  def mctwf_first_saturday_of_month
    x = mctwf_last_saturday_of_month
    while (x.day > 7) do 
        x -= 7
    end
    x
  end


end
