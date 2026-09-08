ALTER TABLE olist_data_mart.map_delivered_order_to_event
ADD CONSTRAINT fk_map_order_event
    FOREIGN KEY (order_event_key)
    REFERENCES olist_data_mart.fact_delivered_order_event(order_event_key);