-- The mobile app supports tipping, folded into `total` with no separate
-- column — order detail/receipt screens need to show it as its own line.
alter table orders add column tip numeric(10,2) not null default 0;
