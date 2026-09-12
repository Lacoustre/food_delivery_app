-- One payment must mean one order.
--
-- Order #1007 was a phantom: the browser's create-order and the Stripe webhook
-- both ran for payment pi_3UExPxGPb7JNV9AP0XJoY0nm, 416ms apart, and both
-- inserted. The webhook guards against this by checking whether an order
-- already carries the payment — but that is a read followed by a write, and
-- both read before either wrote.
--
-- #1007 is removed rather than cancelled. It has no Clover ticket, no Uber
-- delivery and no payment of its own; it is an artefact, and leaving it as a
-- cancelled order would double-count $63.79 in any revenue report that
-- includes cancellations. The real order is #1008, and Stripe holds the
-- authoritative payment record either way.
delete from order_items
where order_id in (select id from orders where order_number = '1007');

delete from orders where order_number = '1007';

-- The check the application could not make safely, made by the database
-- instead. Now whichever path is second gets a unique violation rather than
-- creating a second order, and both routes treat that as "the order already
-- exists", which it does.
--
-- Partial, because cash orders legitimately have no payment intent and there
-- may be many of them.
create unique index if not exists orders_payment_intent_id_key
  on orders (payment_intent_id)
  where payment_intent_id is not null;

-- Refuse to apply if any other payment already has two orders against it,
-- rather than failing halfway with an index that cannot be built.
do $$
declare
  dupes int;
begin
  select count(*) into dupes from (
    select payment_intent_id
    from orders
    where payment_intent_id is not null
    group by payment_intent_id
    having count(*) > 1
  ) x;

  if dupes > 0 then
    raise exception '% payment(s) still have more than one order', dupes;
  end if;
end $$;
