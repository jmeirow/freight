
require 'bigdecimal'

  class Money 
    def initialize amt 
      @money = BigDecimal(amt.to_s, 15).round(2)
    end

    def * amt
      Money.new((money * amt.amount).round(2).to_s)
    end

    def + amt
      Money.new((money + amt.amount).round(2).to_s)
    end

    def - amt
      Money.new((money - amt.amount).round(2).to_s)
    end

    def == amt
      money == amt.amount
    end

    def >= amt
      money >= amt.amount
    end

    def <= amt
      money <= amt.amount
    end

    def > amt
      money > amt.amount
    end

    def < amt
      money < amt.amount
    end

    def / divisor 
      raise "divisor must be a Fixnum (integer)" if divisor.class != Fixnum 
      Money.new(money / divisor)
    end

    def to_s
      x = "%.2f" % money.to_f
      "$#{x}"
    end

    def amount
      money 
    end

    private

    def money
      @money
    end

    def method_missing *args
      puts "#{args[0]} is not supported by Money."
      super args
    end

  end
