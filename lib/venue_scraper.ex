defmodule VenueScraper do
  @moduledoc """
  Documentation for VenueScraper.
  """

  @doc """
  Hello world.

  ## Examples

      iex> VenueScraper.hello
      :world

  """
  @lastfm_url "https://ws.audioscrobbler.com/2.0/"
  @lastfm_api_key Application.get_env(:venue_scraper, :lastfm_api_key)

  def get_bands_for(user \\ "SP420") do
    url = @lastfm_url <> "?method=user.gettopartists&user=#{user}&api_key=#{@lastfm_api_key}&format=json&period=overall&limit=500"
    fetch_bands(url, 1)
  end

  def fetch_bands(url, page, artists \\ [])
  def fetch_bands(url, page, artists) do
    case HTTPoison.get(url <> "&page=#{page}") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        new_artists = Poison.decode!(body)
        |> Map.get("topartists")
        |> Map.get("artist")
        |> Enum.map(&(&1["name"]))

        if Enum.count(new_artists) > 0 do
          fetch_bands(url, page + 1, artists ++ new_artists)
        else
          artists ++ new_artists
        end
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect(reason)
    end
  end

  def sw do
    # url = "https://www.thesidewinderaustin.com/"
    # HTTPoison.get!(url).body
    keys = ~W[title presents description id starts_at doors_at]

    File.read!("./lib/20170409_sidewinder.json")
    |> Poison.decode!
    |> Enum.map(&(Map.take(&1, keys)))
  end

  def bands_at_venue?(user_bands, venue_bands) do
    intersection = MapSet.intersection(MapSet.new(user_bands), MapSet.new(venue_bands))
    MapSet.size(intersection) > 0
  end
end
