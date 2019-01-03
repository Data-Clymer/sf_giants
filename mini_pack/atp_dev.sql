//average ticket price by financial_patron_account_id 
CREATE OR REPLACE VIEW MINI_PACK.ATP AS
SELECT 
    a.FINANCIAL_PATRON_ACCOUNT_ID,
    count(a.ticket_id) AS NumberofTix,
    ROUND(AVG(a.PRICE), 2) AS ATP,
    CASE
        WHEN ATP > 39 THEN 1
        ELSE 0
    END AS high_spender
FROM tdc.event_seat a
GROUP BY 1;

//median ticket price
SELECT 
    MEDIAN(ATP)
FROM mini_pack.ATP;