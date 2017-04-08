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
    |> Enum.map(&(Map.get(&1, "name")))
  end
end
