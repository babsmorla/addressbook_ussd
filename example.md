class MomoController < ApplicationController
  before_action :initialize_session

  def index
    # The USSD window is active only if the session has started
    @ussd_active = session[:ussd_active]

    if @ussd_active
      raw_ussd_response = process_ussd(session[:ussd_history])
      @is_end_screen = raw_ussd_response.start_with?("END")
      @display_text = raw_ussd_response.sub(/^(CON|END)\s*/, "")
      @menu_lines = @display_text.split("\n")
    else
      # If not active, show whatever the user has typed on the dial screen so far
      @dial_screen = session[:dial_buffer] || ""
    end
  end

  def submit
    # 1. HARD RESET / CANCEL
    if params[:commit] == "Reset"
      reset_momo_session
      redirect_to root_path and return
    end

    # 2. CLEAR / BACKSPACE BUTTON HANDLING
    if params[:commit] == "Clear"
      unless session[:ussd_active]
        # Remove the last character from the dialing buffer string
        session[:dial_buffer] = session[:dial_buffer].to_s.chop
      end
      redirect_to root_path and return
    end

    # 3. KEYPAD BUTTON PRESS HANDLING
    if params[:key_value].present?
      key = params[:key_value]
      if session[:ussd_active]
        flash[:append_key] = key
      else
        session[:dial_buffer] = "#{session[:dial_buffer]}#{key}"
      end
      redirect_to root_path and return
    end

    # 4. GREEN DIAL / SEND BUTTON HANDLING
    if session[:ussd_active]
      user_input = params[:user_input].to_s.strip
      
      if @is_end_screen || params[:commit] == "Dismiss"
        reset_momo_session
      elsif user_input.present?
        if session[:ussd_history].empty?
          session[:ussd_history] = user_input
        else
          session[:ussd_history] = "#{session[:ussd_history]}*#{user_input}"
        end
      end
    else
      if session[:dial_buffer] == "*170#"
        session[:ussd_active] = true
        session[:ussd_history] = ""
      else
        flash[:error] = "Unknown short code. Try dialing *170# for MTN MoMo."
        session[:dial_buffer] = ""
      end
    end

    redirect_to root_path
  end

  private

  def initialize_session
    session[:ussd_history] ||= ""
    session[:dial_buffer] ||= ""
    session[:ussd_active] ||= false
  end

  def reset_momo_session
    session[:ussd_history] = ""
    session[:dial_buffer] = ""
    session[:ussd_active] = false
  end

  # ===================================================
  # USSD MENU TREE ENGINE
  # ===================================================
  def process_ussd(history_string)
    steps = history_string.present? ? history_string.split('*') : []

    if steps.empty?
      return "CON Welcome to MTN MoMo\n1. Transfer Money\n2. Airtime & Bundles\n3. My Wallet"
    end

    case steps[0]
    when "1"
      transfer_money_flow(steps)
    when "2"
      "END Airtime vending channels are undergoing scheduled maintenance."
    when "3"
      "END Balance Check:\n\nAvailable Balance: GHS 520.00\nTransaction Fee: GHS 0.00"
    else
      "END Unknown prompt code selection. Session disconnected."
    end
  end

  def transfer_money_flow(steps)
    case steps.length
    when 1
      "CON Transfer Money\n1. MoMo User\n2. Other Networks\n0. Back"
    when 2
      if steps[1] == "1"
        "CON Enter Recipient Mobile Number:"
      elsif steps[1] == "0"
        session[:ussd_history] = ""
        "CON Returning to main menu...\nPress Send to refresh."
      else
        "END Interoperability channel offline."
      end
    when 3
      "CON Enter Amount (GHS):"
    when 4
      "CON Transfer GHS #{steps[3]} to #{steps[2]}?\n1. Confirm\n2. Cancel"
    when 5
      if steps[4] == "1"
        "END Success! GHS #{steps[3]} transferred to #{steps[2]}. Ref: #{rand(100000..999999)}."
      else
        "END Transaction abandoned."
      end
    else
      "END Session runtime error."
    end
  end
end












<div class="smartphone-frame">
  <div class="smartphone-screen">
    <% if @ussd_active %>
      <!-- ========================================== -->
      <!-- STATE A: ACTIVE USSD OVERLAY WINDOW MODE  -->
      <!-- ========================================== -->
      <div></div>
      <!-- Spacer -->
      <div class="ussd-alert-box">
        <div class="ussd-header"><%= @menu_lines.first %></div>
        <% @menu_lines.drop(1).each do |line| %>
          <div class="ussd-row"><%= line %></div>
        <% end %>
        <%= form_with url: momo_submit_path, local: true, id: 'ussd-form' do |f| %>
          <% unless @is_end_screen %>
            <!-- Set value dynamically if a button pad was clicked -->
            <%= f.text_field :user_input, 
                             value: flash[:append_key], 
                             id: 'ussd-input-field',
                             autofocus: true, 
                             autocomplete: "off", 
                             class: "ussd-input" %>
          <% end %>
          <div class="button-group">
            <% if @is_end_screen %>
              <%= f.submit "Dismiss", class: "action-btn", style: "color: #333;" %>
            <% else %>
              <%= f.submit "Cancel", name: "commit", value: "Reset", class: "action-btn", style: "color: #888;" %>
              <%= f.submit "Send", class: "action-btn" %>
            <% end %>
          </div>
        <% end %>
      </div>
      <div></div>
      <!-- Spacer -->
    <% else %>
      <!-- ========================================== -->
      <!-- STATE B: PHONE KEYPAD DIALER SYSTEM MODE  -->
      <!-- ========================================== -->
      <div>
        <div class="dialer-display">
          <%= @dial_screen.presence || "—" %>
        </div>
        <% if flash[:error] %>
          <div class="dialer-error"><%= flash[:error] %></div>
        <% end %>
      </div>
      <%= form_with url: momo_submit_path, local: true do |f| %>
        <div class="dialpad-container">
          <% %w[1 2 3 4 5 6 7 8 9 * 0 #].each do |digit| %>
            <button type="submit" name="key_value" value="<%= digit %>" class="key-btn">
              <%= digit %>
            </button>
          <% end %>
          <%= f.submit "Dial", class: "dial-btn" %>
          <%= f.submit "Clear", name: "commit", value: "Clear", class: "clear-btn" %>
        </div>
      <% end %>
    <% end %>
    <!-- State Trace Debug Console Footer -->
    <div class="debug-panel">
      <strong>Active USSD String Trace:</strong><br>
      params[:text] = "<%= session[:ussd_history].presence || '(blank)' %>"
    </div>
  </div>
</div>
<!-- Quick JS Helper: If a key is punched during a session, add it straight into the text container -->
<script>
  document.querySelectorAll('.key-btn').forEach(button => {
    button.addEventListener('click', (e) => {
      const inputField = document.getElementById('ussd-input-field');
      if (inputField) {
        e.preventDefault();
        inputField.value += button.value;
        inputField.focus();
      }
    });
  });
</script>






<!DOCTYPE html>
<html>
  <head>
    <title>MTN MoMo Engine Simulator</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
   <style>
  /* Base Reset & Centering Layout Workspace */
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background-color: #f0f2f5;
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    margin: 0;
  }

  /* Physical Smartphone Device Chassis Border Rim Frame */
  .smartphone-frame {
    width: 360px;
    height: 720px;
    background: #111;
    border-radius: 44px;
    padding: 14px;
    box-shadow: 0 25px 50px -12px rgba(0,0,0,0.25);
    display: flex;
  }

  /* Active Operating Screen Layer with MTN Corporate Palette */
  .smartphone-screen {
    flex: 1;
    background: #ffcc00; /* MTN Core Yellow */
    border-radius: 34px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    position: relative;
    overflow: hidden;
  }

  /* Dialer Engine Top Value Screen Component Display */
  .dialer-display {
    height: 80px;
    background: rgba(255, 255, 255, 0.9);
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 28px;
    font-weight: bold;
    color: #222;
    letter-spacing: 2px;
    margin-top: 40px;
    box-shadow: inset 0 2px 4px rgba(0,0,0,0.05);
  }

  /* Flash Error Notification Messaging Framework Alert Box */
  .dialer-error {
    color: #d32f2f;
    font-size: 12px;
    text-align: center;
    background: #ffebee;
    padding: 6px;
    border-radius: 6px;
    margin-top: 8px;
    font-weight: 500;
  }

  /* Floating Pop-Up USSD Overlay Modal Dialog Dialogue Canvas */
  .ussd-alert-box {
    background: #ffffff;
    border-radius: 14px;
    padding: 20px;
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.15);
    margin-top: auto;
    margin-bottom: auto;
    z-index: 10;
  }

  /* Dynamic Title/Heading Prompt Layer of USSD Responses */
  .ussd-header {
    font-size: 15px;
    font-weight: 700;
    color: #1a1a1a;
    margin-bottom: 12px;
    line-height: 1.4;
  }

  /* Sub-Selection Navigation Options Menu Items Content Lines */
  .ussd-row {
    font-size: 14px;
    color: #4a4a4a;
    margin: 5px 0;
  }

  /* Clean Native Input Interface Border Element Config */
  .ussd-input {
    width: 100%;
    box-sizing: border-box;
    border: none;
    border-bottom: 2px solid #ffcc00;
    padding: 8px 0;
    font-size: 16px;
    margin-top: 14px;
    outline: none;
    color: #000;
    background: transparent;
  }

  /* Active 3x4 Grid Key Matrix Interface Map Block */
  .dialpad-container {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
    margin-bottom: 10px;
    padding: 0 10px;
  }

  /* Individual Spherical Dial Pad Numeric Interactive Keys Layout */
  .key-btn {
    background: rgba(255, 255, 255, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 50%;
    width: 60px;
    height: 60px;
    margin: 0 auto;
    font-size: 22px;
    font-weight: 600;
    color: #111;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.1s ease, transform 0.05s ease;
  }

  .key-btn:active {
    background: rgba(255, 255, 255, 0.5);
    transform: scale(0.95);
  }

  /* Shared Base Ruleset For Lower Row Action Handles */
  .dial-btn, .clear-btn {
    height: 50px;
    border: none;
    font-weight: bold;
    cursor: pointer;
    text-transform: uppercase;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    transition: background-color 0.1s ease, transform 0.05s ease;
  }

  .dial-btn:active, .clear-btn:active {
    transform: scale(0.98);
  }

  /* Secondary Green Dial Submission Operational Vector */
  .dial-btn {
    background: #2e7d32;
    color: #fff;
    grid-column: span 2;
    border-radius: 30px;
    font-size: 16px;
  }

  .dial-btn:active {
    background: #1b5e20;
  }

  /* Accent Variant Crimson Destructive Eraser Action Control Element */
  .clear-btn {
    background: #c62828;
    color: #fff;
    grid-column: span 1;
    border-radius: 30px;
    font-size: 14px;
  }

  .clear-btn:active {
    background: #b71c1c;
  }

  /* Form Submission Internal Inline Navigation Elements Flex Wrap */
  .button-group {
    display: flex;
    justify-content: flex-end;
    gap: 20px;
    margin-top: 20px;
  }

  .action-btn {
    background: none;
    border: none;
    font-size: 15px;
    font-weight: 700;
    color: #0066cc;
    cursor: pointer;
    text-transform: uppercase;
    padding: 4px;
  }

  /* Debug Analytics Terminal Overlay Panel Footer */
  .debug-panel {
    background: rgba(0,0,0,0.05);
    padding: 8px;
    border-radius: 8px;
    font-family: monospace;
    font-size: 10px;
    color: #444;
    text-align: center;
    margin-top: 10px;
  }
</style>
  </head>
  <body>
    <%= yield %>
  </body>
</html>

