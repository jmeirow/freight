require 'date'

class Date


  def mctwf_sunday_of_week
    return self if self.wday == 0
    self - self.wday
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
