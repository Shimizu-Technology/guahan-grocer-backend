class AddAcceptedStatusToOrders < ActiveRecord::Migration[8.0]
  def up
    # Update existing status values to accommodate the new 'accepted' status
    # Current: pending=0, shopping=1, delivering=2, delivered=3, cancelled=4
    # New:     pending=0, accepted=1, shopping=2, delivering=3, delivered=4, cancelled=5
    
    # Shift existing values to make room for 'accepted'
    execute("UPDATE orders SET status = 5 WHERE status = 4") # cancelled: 4 -> 5
    execute("UPDATE orders SET status = 4 WHERE status = 3") # delivered: 3 -> 4  
    execute("UPDATE orders SET status = 3 WHERE status = 2") # delivering: 2 -> 3
    execute("UPDATE orders SET status = 2 WHERE status = 1") # shopping: 1 -> 2
    # pending stays at 0, accepted will be 1
  end
  
  def down
    # Reverse the migration - shift values back
    execute("UPDATE orders SET status = 1 WHERE status = 2") # shopping: 2 -> 1
    execute("UPDATE orders SET status = 2 WHERE status = 3") # delivering: 3 -> 2
    execute("UPDATE orders SET status = 3 WHERE status = 4") # delivered: 4 -> 3
    execute("UPDATE orders SET status = 4 WHERE status = 5") # cancelled: 5 -> 4
    # Remove any 'accepted' status orders by setting them to pending
    execute("UPDATE orders SET status = 0 WHERE status = 1") # accepted: 1 -> pending: 0
  end
end
