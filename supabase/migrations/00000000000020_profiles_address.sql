-- The webapp profile screen keeps a free-text default delivery address.
alter table profiles add column if not exists address text;
