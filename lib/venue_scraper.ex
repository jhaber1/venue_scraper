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

  def get_bands(user \\ "SP420") do
    url = @lastfm_url <> "?method=user.gettopartists&user=#{user}&api_key=#{@lastfm_api_key}&format=json&limit=10"

    HTTPoison.get!(url).body
    |> Poison.decode!
    |> Map.get("topartists")
    |> Map.get("artist")
    |> Enum.map(&(&1["name"]))
  end

  def swb do
    # url = "https://www.thesidewinderaustin.com/"
    # HTTPoison.get!(url).body
    keys = ~W[title presents description id starts_at doors_at]

    events = File.read!("./lib/20170409_sidewinder.json") |> Poison.decode!
    for event <- events do
      Enum.reduce(event, %{}, fn({k, v}, result) ->
        if Enum.member?(keys, k), do: Map.put(result, k, v), else: result
      end)
    end
  end
end
