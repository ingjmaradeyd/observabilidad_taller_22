from collections.abc import Awaitable, Callable


async def create_order_workflow(
    payload: dict[str, object],
    *,
    customer_lookup: Callable[[int], Awaitable[dict[str, object] | None]],
    order_creator: Callable[[dict[str, object]], Awaitable[dict[str, object]]],
):
    customer = await customer_lookup(int(payload["id_cliente"]))
    if customer is None:
        return None

    return await order_creator(payload)
