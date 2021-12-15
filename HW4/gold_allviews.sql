SELECT * bmbln_homework.gold_allviews
    WITH (
          format = 'PARQUET',
          parquet_compression = 'SNAPPY',
          external_location = 's3://bmbln/datalake/gold_allviews'
    ) AS SELECT 
    article, 
    SUM(views) AS total_top_view, 
    COUNT(*) AS ranked_days,
    MIN(rank) AS total_rank
         FROM bmbln_homework.silver_views
         GROUP BY article;