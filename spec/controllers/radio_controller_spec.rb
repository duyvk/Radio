require File.dirname(__FILE__) + '/../spec_helper'

def expected_update_data(*pieces)
  {
    :playlist => @radio.dj.playlist.serialize_for_client,
    :player => {
      :status => Player.status,
      :current_track => @radio.dj.playlist.current_track.id
    },
    :next_update_time => 5.seconds
  }.select do |key, value|
    pieces.include?(key)
  end
end

describe RadioController do
  set_fixture_class :djs => "DJ" # Why can't I find a way to set this globally?

  before(:each) do
    @radio = radio_apps :radio
    @user = users :josh

    @current_track = tracks :tracks_0158
    @next_track = tracks :tracks_0107

    Rails.cache.delete :player_action
  end

  describe :index do
    it "should load the index page" do
      get :index

      assigns(:users).should == User.by_name
      assigns(:radio).should == @radio

      response.should be_success
      response.should render_template("radio/index")
      response.should render_template("layouts/application")
    end
  end

  describe :update do
    it "should not serve update data if not authenticated" do
      get :update, :request => "all"

      response.code.should == "401"
      response.content_type.should == "text/html"
      response.body.should == "You need to log in first!"
    end

    it "should render all update data" do
      sign_in @user

      get :update, :request => "all"

      assigns(:user).should == @user
      assigns(:radio).should == @radio

      response.should be_success
      response.code.should == "200"
      response.content_type.should == "application/json"
      response.body.should == expected_update_data(:playlist, :player, :next_update_time).to_json
    end

    it "should render specific update data" do
      sign_in @user

      get :update, :request => "player"

      assigns(:user).should == @user
      assigns(:radio).should == @radio

      response.should be_success
      response.code.should == "200"
      response.content_type.should == "application/json"
      response.body.should == expected_update_data(:player, :next_update_time).to_json
    end
  end

  describe :play do
    it "should not run play if not authenticated" do
      get :play, :track => @current_track.id

      response.code.should == "401"
      response.content_type.should == "text/html"
      response.body.should == "You need to log in first!"
    end

    it "should not run play and serve correct data if user requests with the track that isn't the current one" do
      sign_in @user

      get :play, :track => @next_track.id

      assigns(:user).should == @user
      assigns(:radio).should == @radio
      assigns(:track).should == @next_track

      response.code.should == "406"
      response.content_type.should == "application/json"
      response.body.should == expected_update_data(:playlist, :player).to_json
    end

    it "should run play and return updated playlist and player status" do
      sign_in @user

      get :play, :track => @current_track.id

      assigns(:user).should == @user
      assigns(:radio).should == @radio
      assigns(:track).should == @current_track

      Rails.cache.fetch(:player_action).should == :play

      response.should be_success
      response.code.should == "200"
      response.content_type.should == "application/json"
      response.body.should == expected_update_data(:playlist, :player).to_json
    end
  end

  describe :pause do
    it "should not run pause if not authenticated" do
      get :pause, :track => @current_track.id

      response.code.should == "401"
      response.content_type.should == "text/html"
      response.body.should == "You need to log in first!"
    end

    it "should not run pause and render update data if user requests with non-current track" do
      sign_in @user

      get :pause, :track => @next_track.id

      assigns(:user).should == @user
      assigns(:radio).should == @radio
      assigns(:track).should == @next_track

      response.code.should == "406"
      response.content_type.should == "application/json"
      response.body.should == expected_update_data(:playlist, :player).to_json
    end

    it "should pause and render update data" do
      sign_in @user

      get :pause, :track => @current_track.id

      assigns(:user).should == @user
      assigns(:radio).should == @radio
      assigns(:track).should == @current_track

      Rails.cache.fetch(:player_action).should == :pause

      response.should be_success
      response.code.should == "200"
      response.content_type.should == "application/json"
      response.body.should == expected_update_data(:player).to_json
    end
  end

  describe :veto do
    it "should not run veto if not authenticated" do
      get :veto, :track => @current_track.id

      response.code.should == "401"
      response.content_type.should == "text/html"
      response.body.should == "You need to log in first!"
    end

    it "should not run veto and render update data if user requests with a non-current track" do
      sign_in @user

      get :veto, :track => @next_track.id

      assigns(:user).should == @user
      assigns(:radio).should == @radio
      assigns(:track).should == @next_track

      response.code.should == "406"
      response.content_type.should == "application/json"
      response.body.should == expected_update_data(:playlist, :player).to_json
    end

    it "should veto track and render update data" do
      sign_in @user

      @user.vetoes.size.should == 3
      @current_track.vetoes.size.should == 0

      @radio.dj.playlist.tracks.should include(@current_track)
      @radio.dj.playlist.tracks.size.should == 24

      expect {
        expect {
          get :veto, :track => @current_track.id
        }.to change(PlaylistTrack, :count).by(-1)
      }.to change(Veto, :count).by(1)

      assigns(:user).should == @user
      assigns(:radio).should == @radio
      assigns(:track).should == @next_track

      Rails.cache.fetch(:player_action).should == :play

      @user.vetoes(true).size.should == 4
      @current_track.vetoes(true).size.should == 1

      @radio.dj.playlist.tracks(true).should_not include(@current_track)
      @radio.dj.playlist.tracks.size.should == 23
      @radio.dj.playlist.current_track.should == @next_track

      response.code.should == "200"
      response.content_type.should == "application/json"
      response.body.should == expected_update_data(:playlist, :player).to_json
    end
  end

  describe :get_track do
    [:play, :pause, :veto].each do |action|
      it "should run get track for action '#{action}' and successfully get track" do
        sign_in @user

        Player.stub!(:play).and_return(true) if action == :play

        get action, :track => @current_track.id

        assigns(:track).should == (action == :veto ? @next_track : @current_track)

        response.should be_success
      end

      it "should run get track for action '#{action}' and return update data if user requests with non-current track" do
        sign_in @user

        get action, :track => @next_track.id

        assigns(:track).should == @next_track

        response.code.should == "406"
        response.content_type.should == "application/json"
        response.body.should == expected_update_data(:playlist, :player).to_json
      end
    end

    [:index, :update].each do |action|
      it "should not run for action '#{action}'" do
        sign_in @user unless action == :index
        get action, :track => @current_track.id, :request => (action == :update ? "all" : nil)

        response.should be_success

        assigns(:track).should be_nil
      end
    end
  end

  describe :maintain_playlist do
    before(:each) do
      @radio.dj.playlist.tracks.delete(@radio.dj.playlist.tracks - [@current_track])
    end

    [:index, :update, :play, :pause, :veto].each do |action|
      it "should run maintain playlist for action '#{action}'" do
        sign_in @user unless action == :index

        Player.stub!(:play).and_return(true) if action == :play

        @radio.dj.playlist.tracks.size.should == 1
        @radio.dj.need_to_run?.should be true

        get action, :track => ([:play, :pause, :veto].include?(action) ? @current_track.id : nil), :request => (action == :update ? "all" : nil)

        response.should be_success

        @radio.reload
        @radio.dj.playlist.tracks.size.should > 1
      end
    end
  end

  describe :set_player_action do
    it "should set the player action on play request" do
      sign_in @user

      Rails.cache.fetch(:player_action).should be nil

      get :play, :track => @current_track.id

      response.should be_success

      Rails.cache.fetch(:player_action).should == :play
    end
  end
end
