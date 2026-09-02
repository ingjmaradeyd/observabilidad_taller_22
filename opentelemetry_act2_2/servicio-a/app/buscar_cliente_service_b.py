from app.dependencies import find_customer


async def buscar_cliente(cliente_id: int):
    return await find_customer(cliente_id)
