-- pack_mapping view creation
CREATE OR REPLACE VIEW MINI_PACK.PACK_MAPPING AS 
SELECT
  a.description,
  a.last_updated_date,
  a.buyer_type_id,
  a.buyer_type_code,
  a.max_offer_tixx_limit,
  CASE 
    WHEN lower(a.description) like '%open%' or lower(a.description) like '%nyy%' or 
        lower(a.description) like '%bonds%' or lower(a.description) like '%alaska%' or 
        lower(a.description) like '%boston%' or lower(a.description) like '%ada0d4%' or
        lower(a.description) like 'od %' or lower(a.description) like '%sox six pack%' or
        lower(a.description) like '%vapk17%' THEN 'Jewel' 
    WHEN lower(a.description) like '%holiday%' or lower(a.description) like '%nutcracker%' THEN 'Holiday'
    ELSE 'Standard' 
  END AS buyer_type_regroup
FROM TDC.buyer_type a
INNER JOIN TDC.buyer_type_group b 
  ON a.BUYER_TYPE_GROUP_ID=b.BUYER_TYPE_GROUP_ID
WHERE b.BUYER_TYPE_GROUP_CODE = 'MINPKS';

-- minipack ticket count by financial_patron_account_id/buyer_type_code combo for last 3 seasons
CREATE OR REPLACE VIEW MINI_PACK.PATRON_PACK_PURCHASES AS
SELECT 
    financial_patron_account_id,
    buyer_type_code,
    ticket_count,
    ROUND(
      CASE 
        WHEN lower(buyer_type_code) IN ('frd2pk', 'fil2pk', 'grdpk1', 'grdpk2', 'grdpkj', 'grdpkm', 'pr2pk') THEN ticket_count/2
        WHEN lower(buyer_type_code) IN ('18od3p', 'citypk', 'ss3pk', 'sunpk') THEN ticket_count/3
        WHEN lower(buyer_type_code) IN ('18od4p', 'adaod4', 'adapck', 'alaska', '18bbpk', 'bos4pk', 'flx4pk', '4ever', 'fwpk17', 'nlpspk', 'odhrpk', 'odnlwp', 'odvpck', 'odpk17', 'od4pk', 'pushpk', 'sapk17', 'vapk17') THEN ticket_count/4
        WHEN lower(buyer_type_code) IN ('18hol2', '18od6p', '19hldy', 'hpack1', 'hpack2', 'od6pk', 'on6pk', 'sox6pk') THEN ticket_count/6
        ELSE 0
      END,1) AS mini_pack_count 
FROM (
  SELECT
      a.FINANCIAL_PATRON_ACCOUNT_ID,
      a.buyer_type_id,
      c.buyer_type_code,
      COUNT(DISTINCT a.ticket_id) AS ticket_count
  FROM tdc.event_seat a
  INNER JOIN tdc.event b
      ON a.event_id = b.event_id
  INNER JOIN tdc.buyer_type c
      ON a.buyer_type_id = c.buyer_type_id
  INNER JOIN tdc.BUYER_TYPE_GROUP d 
      ON c.BUYER_TYPE_GROUP_ID = d.BUYER_TYPE_GROUP_ID
  WHERE b.event_run_id IN ('2702', '2301', '2541')  AND
      d.buyer_type_group_code='MINPKS'
  GROUP BY 1,2,3)
;

-- minipack purchase count by financial_patron_account_id/buyer_type_regroup combo
CREATE OR REPLACE VIEW MINI_PACK.PATRON_MINIPACK_REGROUP_RANKING AS
SELECT 
    a.FINANCIAL_PATRON_ACCOUNT_ID,
    b.buyer_type_regroup,
    SUM(a.mini_pack_count) AS minipack_purchase_count,
    DENSE_RANK() OVER(PARTITION BY financial_patron_account_id ORDER BY minipack_purchase_count DESC) AS minipack_group_rank
FROM patron_pack_purchases a
JOIN pack_mapping b
    ON a.buyer_type_code = b.buyer_type_code
GROUP BY 1,2
ORDER BY 1;     

-- most purchased minipack by financial_patron_account_id
CREATE OR REPLACE VIEW MINI_PACK.PATRON_MOST_COMMON_BUYER_TYPE AS
SELECT
    financial_patron_account_id,
    minipack_purchase_count,
    MAX(buyer_type_regroup) AS most_common_buyer_type_regroup
FROM patron_minipack_regroup_ranking
WHERE minipack_group_rank = 1
GROUP BY 1,2;

-- average ticket price by financial_patron_account_id 
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

-- median ticket price
SELECT 
    MEDIAN(ATP)
FROM mini_pack.ATP;

-- patron categorization (most common minipack purchase type and ATP threshold)
CREATE OR REPLACE VIEW MINI_PACK.PATRON_CATEGORIES AS
SELECT 
    a.financial_patron_account_id,
    a.most_common_buyer_type_regroup,
    b.high_spender,
    CASE
        WHEN a.most_common_buyer_type_regroup = 'Holiday' AND b.high_spender = 1 THEN 'Holiday High Spender'
        WHEN a.most_common_buyer_type_regroup = 'Holiday' AND b.high_spender = 0 THEN 'Holiday Low Spender'
        WHEN a.most_common_buyer_type_regroup = 'Jewel' AND b.high_spender = 1 THEN 'Jewel High Spender'
        WHEN a.most_common_buyer_type_regroup = 'Jewel' AND b.high_spender = 0 THEN 'Jewel Low Spender'
        WHEN a.most_common_buyer_type_regroup = 'Standard' AND b.high_spender = 1 THEN 'Standard High Spender'
        WHEN a.most_common_buyer_type_regroup = 'Standard' AND b.high_spender = 0 THEN 'Standard Low Spender'
        ELSE 'N/A'
    END AS patron_category
FROM patron_most_common_buyer_type a
JOIN ATP b
    ON a.financial_patron_account_id = b.financial_patron_account_id;    

-- individual dimension view
CREATE OR REPLACE VIEW mini_pack.mini_pack_individual_dim AS 
SELECT 
    a.financial_patron_account_id,
    a.PATRON_ACCOUNT_NAME,
    a.first_name,
    a.last_name,
    a.email,
    a.phone_number,
    b.atp,
    b.numberoftix,
    b.high_spender,
    c.most_common_buyer_type_regroup,
    c.patron_category
FROM ticket_detail a
INNER JOIN ATP b
    ON a.financial_patron_account_id = b.financial_patron_account_id
INNER JOIN patron_categories c
    ON a.financial_patron_account_id = c.financial_patron_account_id
GROUP BY 1,2,3,4,5,6,7,8,9,10,11;


-- TICKET DETAIL DECORATED
-- ticket details (Tableau query)
CREATE OR REPLACE VIEW MINI_PACK.TICKET_DETAIL AS
SELECT TDC.event.event_id,
TDC.event.event_run_id,
TDC.event_seat.seat_id,
TDC.event_seat.ticket_id,
TDC.buyer_type.buyer_type_code,
TDC.Buyer_type.Description BuyerTypeDesc,
TDC.buyer_type_group.buyer_type_group_code,
TDC.event_seat.financial_patron_account_id,
TDC.transaction.transaction_date,
TDC.PATRON_ACCOUNT.PATRON_ACCOUNT_NAME,
TDC.patron_contact.first_name,
TDC.patron_contact.last_name,
TDC.patron_contact_email.email,
TDC.patron_contact_phone.phone_number,
TDC.patron_contact_address.addr1, 
TDC.patron_contact_address.addr2, 
TDC.patron_contact_address.city, 
TDC.patron_contact_address.sub_country_code, 
count(TDC.event_seat.ticket_id) NumberofTix,
sum(TDC.event_seat.PRICE) TotalPrice

FROM TDC.EVENT
INNER JOIN TDC.event_seat ON TDC.event.event_id = TDC.Event_seat.event_id
INNER JOIN TDC.ticket ON TDC.event_seat.ticket_id = TDC.ticket.ticket_id
INNER JOIN TDC.transaction ON TDC.ticket.transaction_id = TDC.transaction.transaction_id
INNER JOIN TDC.BUYER_TYPE ON TDC.event_seat.BUYER_TYPE_ID = TDC.BUYER_TYPE.BUYER_TYPE_ID
INNER JOIN TDC.BUYER_TYPE_GROUP ON TDC.BUYER_TYPE.BUYER_TYPE_GROUP_ID = TDC.BUYER_TYPE_GROUP.BUYER_TYPE_GROUP_ID
INNER JOIN TDC.patron_account on TDC.patron_account.patron_accounT_ID = TDC.event_seat.FINANCIAL_PATRON_ACCOUNT_ID
INNER JOIN TDC.patron_contact on TDC.patron_account.patron_accounT_ID = TDC.patron_contact.patron_account_id
INNER JOIN TDC.patron_contact_address on TDC.patron_contact_address.patron_contact_id=TDC.patron_contact.patron_contact_id
INNER JOIN TDC.patron_contact_email on TDC.patron_contact.patron_contact_id = TDC.patron_contact_email.patron_contact_id
INNER JOIN TDC.patron_contact_phone on TDC.patron_contact.patron_contact_id = TDC.patron_contact_phone.patron_contact_id

WHERE TDC.event.event_run_id IN ('2702', '2301', '2541')
AND TDC.buyer_type_group.buyer_type_group_code='MINPKS'
and TDC.patron_contact.primary=1
and TDC.patron_contact_address.primary=1
and TDC.patron_contact_email.primary=1
and TDC.patron_contact_phone.primary=1

GROUP BY TDC.event.event_id,
TDC.event.event_run_id,
TDC.event_seat.seat_id,
TDC.event_seat.ticket_id,
TDC.buyer_type.buyer_type_code,
TDC.Buyer_type.Description,
TDC.buyer_type_group.buyer_type_group_code,
TDC.event_seat.financial_patron_account_id,
TDC.transaction.transaction_date,
TDC.PATRON_ACCOUNT.PATRON_ACCOUNT_NAME,
TDC.patron_contact.first_name,
TDC.patron_contact.last_name,
TDC.patron_contact_email.email,
TDC.patron_contact_phone.phone_number,
TDC.patron_contact_address.addr1, 
TDC.patron_contact_address.addr2, 
TDC.patron_contact_address.city, 
TDC.patron_contact_address.sub_country_code;

-- ticket detail decorated view
CREATE OR REPLACE VIEW mini_pack.ticket_detail_decorated AS 
SELECT 
    a.event_id,
    a.seat_id,
    a.ticket_id,
    a.buyer_type_code,
    a.BuyerTypeDesc,
    a.buyer_type_group_code,
    a.financial_patron_account_id,
    a.transaction_date,
    a.PATRON_ACCOUNT_NAME,
    a.first_name,
    a.last_name,
    a.email,
    a.phone_number,
    a.addr1, 
    a.addr2, 
    a.city, 
    a.sub_country_code, 
    a.NumberofTix,
    a.TotalPrice,
    b.most_common_buyer_type_regroup, 
    b.high_spender,
    b.patron_category,
    b.atp,
    c.seating_area_type_code,
    d.text_line_1 AS opposing_team
FROM ticket_detail a
INNER JOIN mini_pack_individual_dim b
    ON a.financial_patron_account_id = b.financial_patron_account_id
INNER JOIN tdc.ticket c
    ON a.ticket_id = c.ticket_id
INNER JOIN tdc.event d
    ON a.event_id = d.event_id;    

    
