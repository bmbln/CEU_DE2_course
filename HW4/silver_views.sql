CREATE TABLE bmbln_homework.silver_views
    WITH (
          format = 'PARQUET',
          parquet_compression = 'SNAPPY',
          external_location = 's3://bmbln/datalake/silver_views'
    ) AS SELECT article, views, rank, date
         FROM bmbln_homework.bronze_views
         WHERE date IS NOT NULL;