-- Optimized Low-Risk Doge Betting Script
-- Enhanced for consistent profits with improved risk management

-- Core betting parameters
basebet = 0.00000100         -- Reduced base bet for lower risk
nextbet = basebet
chance = 66                  -- Increased chance for more consistent wins
bethigh = false              -- Always bet low with 66% chance

-- Balance protection
starting_balance = balance
max_risk_percent = 0.5       -- Only risk 0.5% of balance
max_risk_amount = starting_balance * (max_risk_percent / 100)
current_profit = 0
session_peak = starting_balance
lowest_balance = starting_balance

-- Fixed-size betting strategy
small_bet = basebet          -- 0.00000100
medium_bet = basebet * 1.5   -- 0.00000150
large_bet = basebet * 2      -- 0.00000200

-- Pattern targeting
pattern_pos = 1
bet_pattern = {1, 1, 1, 2, 1, 1, 2, 1, 1, 2}  -- More small bets, fewer medium/large

-- Result tracking
win_streak = 0
loss_streak = 0
total_bets = 0
win_count = 0
loss_count = 0
last_result = "none"
last_profit = 0
consecutive_losses_limit = 6 -- Stop after too many consecutive losses

-- Profit protection
profit_lock_percentage = 0.75  -- Lock 75% of profit
locked_profit = 0
recoverable_loss = 0
profit_target = basebet * 50   -- Lower target for more frequent profit locking
take_profit_threshold = starting_balance * 0.02  -- 2% profit target

-- Sequence control
fixed_sequences = {
    {bet=small_bet, wins=0, losses=0},
    {bet=medium_bet, wins=0, losses=0},
    {bet=large_bet, wins=0, losses=0}
}

-- Optimization metrics
profitable_sizes = {true, true, true}
sequence_profit = 0

-- Martingale settings
use_martingale = false       -- Only activate after analysis
martingale_multiplier = 1.2  -- Very conservative multiplier
max_martingale_level = 2     -- Strict limit
martingale_level = 0         -- Initialize martingale level

-- Session control
max_bets = 1000              -- Session bet limit
session_time_limit = 3600    -- 1 hour max session time
session_start_time = os.time()

-- Time-based bet speed control
bet_delay = 0                -- Starts at 0, auto-adjusts
last_bet_time = os.time()

-- Performance metrics
hourly_profit_rate = 0
bets_per_minute = 0
win_rates = {{}, {}, {}}     -- Win rates for each bet size (last 50 bets)
variance = 0                 -- Measure of volatility
rolling_profit = {}          -- Track profit over time for trend analysis
mean_reversion_active = false -- Dynamic feature for variance detection

-- Volatility handling
function calculate_variance()
    if #rolling_profit < 10 then return 0 end
    
    -- Calculate moving average of profit changes
    local sum = 0
    local sum_squares = 0
    local n = math.min(20, #rolling_profit)
    
    for i = #rolling_profit - n + 1, #rolling_profit do
        sum = sum + rolling_profit[i]
    end
    
    local mean = sum / n
    
    for i = #rolling_profit - n + 1, #rolling_profit do
        sum_squares = sum_squares + (rolling_profit[i] - mean)^2
    end
    
    return sum_squares / n
end

function get_bet_size(level)
    if level == 1 then
        return small_bet
    elseif level == 2 then
        return medium_bet
    else
        return large_bet
    end
end

function update_pattern()
    -- Analyze performance of bet sizes
    local best_size = 1
    local best_ratio = 0
    
    for i=1,3 do
        local seq = fixed_sequences[i]
        local total = seq.wins + seq.losses
        local ratio = total > 0 and seq.wins/total or 0
        
        -- Require more data points for reliable analysis
        if total >= 10 then
            profitable_sizes[i] = (ratio >= 0.52)  -- More conservative threshold
        end
        
        if ratio > best_ratio and total >= 10 then
            best_ratio = ratio
            best_size = i
        end
    end
    
    -- Less aggressive pattern modification
    if total_bets > 50 then  -- Wait for more data
        for i=1,#bet_pattern do
            -- Find worst performing size
            local worst_size = 1
            local worst_ratio = 1
            
            for j=1,3 do
                local seq = fixed_sequences[j]
                local total = seq.wins + seq.losses
                local ratio = total > 0 and seq.wins/total or 0
                
                if ratio < worst_ratio and total >= 10 then
                    worst_ratio = ratio
                    worst_size = j
                end
            end
            
            -- Replace worst sizes with best sizes, but conservatively
            if bet_pattern[i] == worst_size and math.random() < 0.15 then  -- 15% chance
                bet_pattern[i] = best_size
            end
            
            -- Always keep majority of pattern as small bets
            local small_bet_count = 0
            for k=1,#bet_pattern do
                if bet_pattern[k] == 1 then
                    small_bet_count = small_bet_count + 1
                end
            end
            
            if small_bet_count < (#bet_pattern * 0.6) then
                -- Force more small bets into pattern
                for k=1,#bet_pattern do
                    if bet_pattern[k] > 1 and math.random() < 0.4 then
                        bet_pattern[k] = 1
                    end
                end
            end
        end
    end
end

-- Comprehensive stop function
function should_stop()
    -- Session time limit (1 hour)
    if os.time() - session_start_time > session_time_limit then
        print("⏰ Session time limit reached")
        return true
    end
    
    -- Max bets limit
    if total_bets >= max_bets then
        print("🔢 Maximum bets limit reached")
        return true
    end
    
    -- Take profit (2% gain)
    if current_profit >= take_profit_threshold then
        print("💰 Take profit target reached: +" .. string.format("%.8f", current_profit))
        return true
    end
    
    -- Stop loss (max risk)
    if current_profit < -max_risk_amount then
        print("🛑 Maximum risk limit reached: " .. string.format("%.8f", current_profit))
        return true
    end
    
    -- Too many consecutive losses
    if loss_streak >= consecutive_losses_limit then
        print("⚠️ Too many consecutive losses: " .. loss_streak)
        return true
    end
    
    -- Extreme drawdown detection (lost over 70% of max risk)
    if current_profit < 0 and math.abs(current_profit) > (max_risk_amount * 0.7) then
        print("📉 Severe drawdown detected, stopping to reassess")
        return true
    end
    
    -- Severe negative trend detection
    if #rolling_profit >= 20 then
        local is_declining = true
        for i = #rolling_profit - 9, #rolling_profit do
            if rolling_profit[i] > rolling_profit[i-10] then
                is_declining = false
                break
            end
        end
        
        if is_declining and current_profit < 0 then
            print("📊 Consistent negative trend detected, stopping to reassess")
            return true
        end
    end
    
    return false
end

function adjust_strategy()
    -- Calculate win ratio safely to avoid division by zero
    local win_ratio = (win_count + loss_count) > 0 and win_count/(win_count + loss_count) or 0.5
    
    -- If win ratio is too low, increase chance
    if total_bets > 50 and win_ratio < 0.48 then
        chance = math.min(chance + 1, 80)
        print("📊 Adjusted chance to " .. chance .. "% for better win rate")
    end
    
    -- If performing well, lock in profit
    if current_profit > 0 and balance > session_peak then
        session_peak = balance
        if current_profit > profit_target then
            local profit_to_lock = (current_profit - profit_target) * profit_lock_percentage
            locked_profit = locked_profit + profit_to_lock
            profit_target = current_profit  -- Move target up
            print("🔒 Locked in profit: " .. string.format("%.8f", locked_profit))
        end
    end
    
    -- Track lowest balance for drawdown measurement
    if balance < lowest_balance then
        lowest_balance = balance
    end
    
    -- Adjust bet speed based on performance
    if win_streak >= 3 then
        bet_delay = math.max(0, bet_delay - 1)  -- Speed up on winning streaks
    elseif loss_streak >= 2 then
        bet_delay = math.min(5, bet_delay + 1)  -- Slow down on losing streaks
    end
    
    -- Calculate hourly profit rate for optimization
    local elapsed_time = os.time() - session_start_time
    if elapsed_time > 60 then -- Need at least a minute of data
        hourly_profit_rate = (current_profit / elapsed_time) * 3600
        bets_per_minute = (total_bets / elapsed_time) * 60
    end
    
    -- Variance-based adjustments
    variance = calculate_variance()
    if variance > 0 and #rolling_profit >= 20 then
        -- In high variance periods, reduce bet sizes temporarily
        if variance > 0.0000001 and not mean_reversion_active then
            small_bet = small_bet * 0.9
            medium_bet = medium_bet * 0.9
            large_bet = large_bet * 0.9
            mean_reversion_active = true
            print("📊 High variance detected, temporarily reducing bet sizes")
        elseif variance < 0.00000005 and mean_reversion_active then
            -- Return to normal when variance reduces
            small_bet = basebet
            medium_bet = basebet * 1.5
            large_bet = basebet * 2
            mean_reversion_active = false
            print("📊 Variance normalized, returning to standard bet sizes")
        end
    end
    
    -- Chance auto-calibration based on performance
    if total_bets % 50 == 0 and total_bets >= 200 then
        -- Fine-tune chance based on actual results vs expected
        local expected_win_rate = chance / 100
        local actual_win_rate = win_count / total_bets
        
        if math.abs(actual_win_rate - expected_win_rate) > 0.03 then
            -- If win rate is significantly different than expected, adjust
            if actual_win_rate < expected_win_rate - 0.03 then
                chance = math.min(chance + 2, 80)
                print("🎯 Increased chance to " .. chance .. "% due to lower than expected win rate")
            elseif actual_win_rate > expected_win_rate + 0.05 then
                chance = math.max(chance - 1, 60)
                print("🎯 Decreased chance to " .. chance .. "% to balance risk/reward")
            end
        end
    end
    
    -- Adaptive bet sizes based on balance trends
    if total_bets % 25 == 0 then
        if current_profit > 0 then
            -- Very small increases on profit
            if win_ratio > 0.52 and current_profit > basebet * 25 then
                small_bet = small_bet * 1.01
                medium_bet = medium_bet * 1.01
                large_bet = large_bet * 1.01
                print("📈 Slightly increased bet sizes due to positive performance")
            end
        else
            -- Quick reductions on losses
            small_bet = math.max(basebet * 0.5, small_bet * 0.95)
            medium_bet = math.max(basebet * 0.75, medium_bet * 0.95)
            large_bet = math.max(basebet, large_bet * 0.95)
            print("📉 Reduced bet sizes to preserve balance")
        end
    end
    
    -- Auto-adjust risk tolerance based on performance
    if total_bets % 100 == 0 and total_bets >= 300 then
        -- If we're doing very well, slightly increase risk
        if current_profit > take_profit_threshold * 0.7 and win_ratio > 0.53 then
            max_risk_percent = math.min(max_risk_percent * 1.1, 0.75)
            max_risk_amount = starting_balance * (max_risk_percent / 100)
            print("📈 Slightly increased risk tolerance to " .. string.format("%.2f", max_risk_percent) .. "%")
        -- If we're struggling, reduce risk
        elseif current_profit < 0 and win_ratio < 0.49 then
            max_risk_percent = math.max(max_risk_percent * 0.9, 0.25)
            max_risk_amount = starting_balance * (max_risk_percent / 100)
            print("📉 Decreased risk tolerance to " .. string.format("%.2f", max_risk_percent) .. "%")
        end
    end
end

function dobet()
    -- Add delay between bets if needed
    if bet_delay > 0 then
        local current_time = os.time()
        if current_time - last_bet_time < bet_delay then
            return  -- Skip this cycle to create delay
        end
        last_bet_time = current_time
    end
    
    -- Update counters
    total_bets = total_bets + 1
    current_profit = balance - starting_balance
    
    -- Add to rolling profit for trend analysis
    table.insert(rolling_profit, current_profit)
    if #rolling_profit > 100 then
        table.remove(rolling_profit, 1)  -- Keep only last 100 values
    end
    
    -- Check stop conditions
    if should_stop() then
        stop()
        return
    end
    
    -- Process result
    if win then
        win_count = win_count + 1
        win_streak = win_streak + 1
        loss_streak = 0
        last_result = "win"
        last_profit = profit
        
        -- Track win for this bet size
        local current_bet_type = bet_pattern[pattern_pos]
        fixed_sequences[current_bet_type].wins = fixed_sequences[current_bet_type].wins + 1
        
        -- Update win rate tracking for this bet size
        table.insert(win_rates[current_bet_type], 1)
        if #win_rates[current_bet_type] > 50 then
            table.remove(win_rates[current_bet_type], 1)
        end
        
        -- Reset to base bet after wins
        use_martingale = false
        martingale_level = 0
    else
        loss_count = loss_count + 1
        loss_streak = loss_streak + 1
        win_streak = 0
        last_result = "loss"
        last_profit = profit
        recoverable_loss = recoverable_loss + nextbet
        
        -- Track loss for this bet size
        local current_bet_type = bet_pattern[pattern_pos]
        fixed_sequences[current_bet_type].losses = fixed_sequences[current_bet_type].losses + 1
        
        -- Update loss rate tracking for this bet size
        table.insert(win_rates[current_bet_type], 0)
        if #win_rates[current_bet_type] > 50 then
            table.remove(win_rates[current_bet_type], 1)
        end
        
        -- Consider martingale after losses, but very carefully
        if loss_streak >= 2 and loss_streak <= max_martingale_level and current_profit > 0 then
            use_martingale = true
            martingale_level = loss_streak
        else
            use_martingale = false
            martingale_level = 0
        end
    end
    
    -- Adjust strategy periodically
    if total_bets % 10 == 0 then
        adjust_strategy()
    end
    
    -- Update pattern periodically
    if total_bets % 25 == 0 then
        update_pattern()
    end
    
    -- Calculate recent win rate for current bet size
    local current_bet_type = bet_pattern[pattern_pos]
    local recent_win_rate = 0
    local win_count_recent = 0
    
    if #win_rates[current_bet_type] > 0 then
        for _, is_win in ipairs(win_rates[current_bet_type]) do
            win_count_recent = win_count_recent + is_win
        end
        recent_win_rate = win_count_recent / #win_rates[current_bet_type]
    end
    
    -- Adaptive bet based on recent performance
    local weight_recent = 0.7  -- Give 70% weight to recent performance
    local weight_overall = 0.3 -- Give 30% weight to overall performance
    local adjusted_win_rate = (recent_win_rate * weight_recent) + ((win_count / total_bets) * weight_overall)
    
    -- Determine next bet amount
    if use_martingale and martingale_level > 0 then
        -- Very conservative martingale only when we have profit
        local martingale_base = small_bet
        nextbet = martingale_base * (martingale_multiplier ^ (martingale_level - 1))
    else
        -- Normal mode follows pattern
        local bet_level = bet_pattern[pattern_pos]
        
        -- Skip unprofitable bet sizes if we have enough data
        if total_bets > 50 and not profitable_sizes[bet_level] then
            -- Find next profitable size
            for i=1,3 do
                if profitable_sizes[i] then
                    bet_level = i
                    break
                end
            end
        end
        
        -- Get base bet size from pattern
        nextbet = get_bet_size(bet_level)
        
        -- Adjust bet based on recent performance (small adjustments)
        if adjusted_win_rate > 0.55 then
            -- Slight increase on good performance
            nextbet = nextbet * (1 + ((adjusted_win_rate - 0.55) * 0.5))
        elseif adjusted_win_rate < 0.48 then
            -- Significant decrease on poor performance
            nextbet = nextbet * (1 - ((0.48 - adjusted_win_rate) * 1.5))
        end
        
        -- Move to next position in pattern
        pattern_pos = pattern_pos + 1
        if pattern_pos > #bet_pattern then
            pattern_pos = 1
        end
    end
    
    -- Apply balance protection limits
    local risk_used = current_profit < 0 and math.abs(current_profit) or 0
    local remaining_risk = max_risk_amount - risk_used
    
    -- Never bet more than 5% of remaining risk allowance
    if nextbet > remaining_risk * 0.05 then
        nextbet = remaining_risk * 0.05
    end
    
    -- Hard limit on max bet
    if nextbet > small_bet * 3 then
        nextbet = small_bet * 3
    end
    
    -- Minimum bet protection (to avoid rounding errors)
    if nextbet < 0.00000001 then
        nextbet = 0.00000001
    end
    
    -- Round bet amount to match observed pattern
    nextbet = math.floor(nextbet * 100000000) / 100000000
    
    -- Log status periodically
    if total_bets % 20 == 0 or (total_bets <= 10) then
        print("Bet #" .. total_bets .. 
              " | Profit: " .. string.format("%.8f", current_profit) ..
              " | Win/Loss: " .. win_count .. "/" .. loss_count ..
              " | Win Rate: " .. string.format("%.2f", (win_count/(win_count+loss_count))*100) .. "%" ..
              " | Risk: " .. string.format("%.2f", (risk_used/max_risk_amount*100)) .. "%")
    end
    
    -- Detailed logging when reaching certain milestones
    if total_bets % 100 == 0 then
        print("======== SESSION SUMMARY ========")
        print("Total Bets: " .. total_bets)
        print("Current Balance: " .. string.format("%.8f", balance))
        print("Session Profit: " .. string.format("%.8f", current_profit) .. 
              " (" .. string.format("%.2f", (current_profit/starting_balance)*100) .. "%)")
        print("Locked Profit: " .. string.format("%.8f", locked_profit))
        print("Win Rate: " .. string.format("%.2f", (win_count/(win_count+loss_count))*100) .. "%")
        print("Hourly Profit Rate: " .. string.format("%.8f", hourly_profit_rate))
        print("Bets Per Minute: " .. string.format("%.1f", bets_per_minute))
        print("Risk Used: " .. string.format("%.2f", (risk_used/max_risk_amount*100)) .. "%")
        print("Variance: " .. string.format("%.10f", variance))
        print("================================")
    end
    
    -- Emergency stop if script is somehow bypassing the should_stop function
    if current_profit < -(max_risk_amount * 1.1) then
        print("🚨 EMERGENCY STOP: Risk limit exceeded")
        stop()
    end
end

-- Initialize session with welcome message
print("▶️ Starting optimized low-risk Doge betting session")
print("🏦 Starting balance: " .. string.format("%.8f", starting_balance))
print("🛡️ Maximum risk: " .. string.format("%.8f", max_risk_amount) .. " (" .. max_risk_percent .. "%)")
print("🎯 Win chance: " .. chance .. "%")
print("⏱️ Session time limit: " .. (session_time_limit/60) .. " minutes")
print("🎮 Max bets: " .. max_bets)
print("💰 Profit target: " .. string.format("%.8f", take_profit_threshold) .. " (" .. (take_profit_threshold/starting_balance*100) .. "%)")
print("================================")