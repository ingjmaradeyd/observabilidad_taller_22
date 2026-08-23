import httpx
import logging
import os

SERVICIO_B = os.getenv("SERVICE_B_URL")


async def buscar_cliente(cliente_id:int):
    async with httpx.AsyncClient() as client:
        logging.info(f"Buscando cliente {cliente_id} en servicio B")
        response = await client.get(f"{SERVICIO_B}/clientes/{cliente_id}")
        if response.status_code != 200:
            return None
        response.raise_for_status()
        return response.json()



