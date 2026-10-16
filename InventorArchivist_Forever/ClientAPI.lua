InventoryArchivistAPI={}
local A=InventoryArchivistAPI
function A.BagSize(bag)
 if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
 if GetContainerNumSlots then return GetContainerNumSlots(bag) end
end
function A.BagItem(bag,slot)
 if C_Container and C_Container.GetContainerItemInfo then
  local v=C_Container.GetContainerItemInfo(bag,slot)
  if v then return {itemID=v.itemID,stackCount=v.stackCount or 1,quality=v.quality,hyperlink=v.hyperlink} end
 end
 if GetContainerItemInfo then
  local _,count,_,quality,_,_,link=GetContainerItemInfo(bag,slot)
  local id=GetContainerItemID and GetContainerItemID(bag,slot)
  if id then return {itemID=id,stackCount=count or 1,quality=quality,hyperlink=link} end
 end
end
function A.GetItemInfo(id)
 if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
 if GetItemInfo then return GetItemInfo(id) end
end
function A.RequestItemInfo(id)
 if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end
function A.CharacterBags()
 local ids={};for i=0,(NUM_BAG_SLOTS or 4) do ids[#ids+1]=i end;return ids
end
function A.BankBags()
 local ids={}
 local bank=Enum and Enum.BagIndex and Enum.BagIndex.Bank
 if type(bank)=='number' then ids[#ids+1]=bank elseif BANK_CONTAINER then ids[#ids+1]=BANK_CONTAINER else ids[#ids+1]=-1 end
 local start=(NUM_BAG_SLOTS or 4)+1
 for i=start,start+(NUM_BANKBAGSLOTS or 7)-1 do ids[#ids+1]=i end
 return ids
end
