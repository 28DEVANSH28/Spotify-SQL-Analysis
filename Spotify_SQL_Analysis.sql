-- create table
DROP TABLE IF EXISTS spotify;
CREATE TABLE spotify (
    artist VARCHAR(255),
    track VARCHAR(255),
    album VARCHAR(255),
    album_type VARCHAR(50),
    danceability FLOAT,
    energy FLOAT,
    loudness FLOAT,
    speechiness FLOAT,
    acousticness FLOAT,
    instrumentalness FLOAT,
    liveness FLOAT,
    valence FLOAT,
    tempo FLOAT,
    duration_min FLOAT,
    title VARCHAR(255),
    channel VARCHAR(255),
    views FLOAT,
    likes BIGINT,
    comments BIGINT,
    licensed BOOLEAN,
    official_video BOOLEAN,
    stream BIGINT,
    energy_liveness FLOAT,
    most_played_on VARCHAR(50)
);

--EDA

SELECT COUNT(*)
FROM spotify

SELECT COUNT(*) - COUNT(artist)
FROM spotify

SELECT COUNT(DISTINCT(artist))AS artist_count
FROM spotify

SELECT DISTINCT(album_type)
FROM spotify

SELECT MAX(duration_min)
FROM spotify

SELECT MIN(duration_min)
FROM spotify

SELECT *
FROM spotify
WHERE duration_min = 0

DELETE FROM spotify
WHERE duration_min = 0

SELECT *
FROM spotify
WHERE duration_min = 0

-- Business Problems

-- 1. Most popular Tracks

SELECT *
FROM spotify
ORDER BY stream DESC
LIMIT 10

-- 2. Artist Portfolio Size

SELECT artist, COUNT(track) tracks_released, SUM(stream) total_streams
FROM spotify
GROUP BY artist
ORDER BY total_streams DESC

-- 3. Album type analysis

SELECT album_type, AVG(stream) average_streams, COUNT(track) total_tracks, SUM(stream) total_streams
FROM spotify
GROUP BY album_type
ORDER BY average_streams DESC

-- 4. Engagement Rate

SELECT 
    track,
    artist,
    album_type,
    likes,
    views,
    ROUND((likes::numeric / NULLIF(views, 0))::numeric,4) AS engagement_rate
FROM spotify
WHERE likes IS NOT NULL AND views IS NOT NULL
ORDER BY engagement_rate DESC NULLS LAST

-- 5. Top 3 tracks per artists

WITH ranked_tracks AS (
SELECT 
	  artist, 
	  track, 
	  stream, 
	  RANK() OVER (PARTITION BY artist ORDER BY stream DESC) AS rank
FROM spotify)

SELECT artist, track, stream, rank
FROM ranked_tracks
WHERE rank <= 3

-- 6. Licensing Impact

SELECT 
	  AVG(views) AS avg_views, 
	  AVG(likes) AS avg_likes, 
	  CASE 
	  	  WHEN licensed = TRUE THEN 'licensed_song' 
		  ELSE 'Unlicensed_song' 
	  END AS song_label
FROM spotify
GROUP BY song_label

-- 7. Energy vs Popularity

WITH energy_labeled AS (
    SELECT 
        stream,
        CASE 
            WHEN energy >= 0 AND energy < 0.2 THEN 'Very Low'
            WHEN energy >= 0.2 AND energy < 0.4 THEN 'Low'
            WHEN energy >= 0.4 AND energy < 0.6 THEN 'Medium'
            WHEN energy >= 0.6 AND energy < 0.8 THEN 'High'
            WHEN energy >= 0.8 AND energy <= 1 THEN 'Very High'
            ELSE 'Out of range'
        END AS energy_group
    FROM spotify
)
SELECT 
    energy_group,
    ROUND(AVG(stream), 2) AS avg_streams
FROM energy_labeled
GROUP BY energy_group
ORDER BY energy_group;

-- 8. Portfolio dependence

WITH artist_track_counts AS (
    SELECT 
        artist, 
        COUNT(*) AS total_tracks
    FROM spotify
    GROUP BY artist
    HAVING COUNT(*) >= 5  -- only artists with 5 or more tracks
),

ranked_tracks AS (
    SELECT 
        artist,
        stream,
        ROW_NUMBER() OVER (PARTITION BY artist ORDER BY stream DESC) AS rank
    FROM spotify
    WHERE stream > 0  -- ignore zero stream tracks in ranking
),

top_streams AS (
    SELECT 
        artist,
        SUM(stream) AS top_3_streams
    FROM ranked_tracks
    WHERE rank <= 3
    GROUP BY artist
),

total_streams AS (
    SELECT 
        artist,
        SUM(stream) AS total_streams
    FROM spotify
    GROUP BY artist
)

SELECT 
    t.artist,
    atc.total_tracks,
    t.total_streams,
    ts.top_3_streams,
    ROUND((ts.top_3_streams * 100.0) / NULLIF(t.total_streams, 0), 2) AS top_3_stream_percentage
FROM total_streams t
JOIN top_streams ts ON t.artist = ts.artist
JOIN artist_track_counts atc ON t.artist = atc.artist
ORDER BY top_3_stream_percentage DESC NULLS LAST;

-- 9. Spotify VS Youtube

WITH engagement AS (
    SELECT 
        track,
        artist,
        album_type,
        most_played_on,
        likes,
        views,
        ROUND((likes::numeric / NULLIF(views::numeric, 0)), 4) AS engagement_rate
    FROM spotify
    WHERE likes IS NOT NULL AND views IS NOT NULL
)

SELECT 
    most_played_on,
    ROUND(AVG(engagement_rate), 4) AS avg_engagement,
    COUNT(*) AS track_count
FROM engagement
GROUP BY most_played_on
ORDER BY avg_engagement DESC NULLS LAST;

-- 10. Album performance KPI

WITH total_streams AS (
    SELECT 
        album, 
        SUM(stream) AS total_sum_streams
    FROM spotify
    GROUP BY album
),
total_views AS (
    SELECT 
        album, 
        SUM(views) AS total_sum_views
    FROM spotify
    GROUP BY album
),
avg_danceability AS (
    SELECT 
        album, 
        ROUND(AVG(danceability)::NUMERIC, 2) AS avg_danceability
    FROM spotify
    GROUP BY album
)

SELECT 
    ts.album,
    ts.total_sum_streams,
    tv.total_sum_views,
    ad.avg_danceability,
    RANK() OVER (ORDER BY ts.total_sum_streams DESC) AS stream_rank
FROM total_streams ts
JOIN total_views tv ON ts.album = tv.album
JOIN avg_danceability ad ON ts.album = ad.album
ORDER BY stream_rank;










