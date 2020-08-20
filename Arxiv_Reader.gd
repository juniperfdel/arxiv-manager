extends Control

var title_arr =  []
var desc_arr  =  []
var link_arr  =  []
var check_arr = []
var curIndex = 0

onready var treeNode = $Background/ButtonList/ArxivHTree
onready var filterListNode = get_node("Background/ButtonList/FilterList")

signal ADSFinished

func getStoredActiveArxivHeader():
	var loadHeaderF = File.new()
	# read the data in
	loadHeaderF.open("arxiv_headers.json", File.READ)
	var textF = loadHeaderF.get_as_text()
	var textArr = JSON.parse(textF).result
	for i in textArr:
		if i.begins_with("*"):
			i = i.replace("*","")
			return i

func getStoredArxivHeaders():
	var loadHeaderF = File.new()
	# read the data in
	loadHeaderF.open("arxiv_headers.json", File.READ)
	var textF = loadHeaderF.get_as_text()
	var textArr = JSON.parse(textF).result
	var textArrB = PoolStringArray()
	for i in textArr:
		if i.begins_with("*"):
			i = i.replace("*","")
		textArrB.append(i)
	return textArrB

func getArxivSelected():
	var curSel = treeNode.get_selected()
	var curName = ""
	var curPar = curSel.get_parent()
	if curPar.get_text(0) == "":
		curName = curSel.get_text(0)
	else:
		curName = curPar.get_text(0) + "." + curSel.get_text(0)
	
	return curName

func buildArxiv():
	var selectedArxiv = getStoredActiveArxivHeader()
	print(selectedArxiv)
	var arxivH = getStoredArxivHeaders()
	var tree = {"topLevel":[]}
	for child in arxivH:
		if child == "":
			continue
		var par = ""
		if child.find(".") > -1:
			par = child.split(".")[0]
			child = child.split(".")[1]
			if child == "":
				child = par
				par = ""
		
		if par == "":
			tree["topLevel"].append(child)
		else:
			if not par in tree.keys():
				tree[par] = [child]
			else:
				tree[par].append(child)
	var root = treeNode.create_item()
	treeNode.set_hide_root(true)
	var parDict = {}
	for tL in tree["topLevel"]:
		var tLN = treeNode.create_item(root)
		tLN.set_text(0,tL)
		parDict[tL] = tLN
	
	for par in tree.keys():
		if par == "topLevel":
			continue
		var parNode = parDict[par]
		if par == selectedArxiv:
			parNode.select(0)
		for child in tree[par]:
			var tCN = treeNode.create_item(parNode)
			tCN.set_text(0,child)
			var nN = par + "." + child
			if nN == selectedArxiv:
				tCN.select(0)

func _ready():
	var filList = loadFilters()
	for fil in filList:
		filterListNode.add_item(fil)
	buildArxiv()
	
	
	
func _on_Open_button_up():
	var curName = getArxivSelected()
	$HTTPRequest.request("http://export.arxiv.org/rss/"+curName)

#if web=true, then was pulled from the rss feed
func parseArxiv(body, web):
	var itemName = "entry"
	var summaryName = "summary"
	var idName = "id"
	if web:
		itemName = "item"
		summaryName = "description"
		idName = "link"
	
	#lets parse this body content
	var p = XMLParser.new()
	var in_item_node = false
	var in_title_node = false
	var in_description_node = false
	var in_link_node = false
	
	p.open_buffer(body)
	
	while p.read() == OK:
		var node_data = ""
		var node_name = ""
		var node_type = p.get_node_type()
		
		# print("node_name: " + node_name)
		# print("node_data: " + node_data)
		# print("node_type: " + node_data)
		
		if (node_type == 3):
			node_data = p.get_node_data()
		
		if ((node_type == 1) or (node_type == 2)):
			node_name = p.get_node_name()
		
		if(node_name == itemName):
			in_item_node = !in_item_node #toggle item mode
		
		if (node_name == "title") and (in_item_node == true):
			in_title_node = !in_title_node
			continue
		
		if(node_name == summaryName) and (in_item_node == true):
			in_description_node = !in_description_node
			continue
			
		if(node_name == idName) and (in_item_node == true):
			in_link_node = !in_link_node
			continue
		
		if(in_description_node == true):
			# print("description-data" + node_data)
			if(node_data != ""):
				desc_arr.append(node_data.replace("<p>","").replace("</p>",""))
			else:
				# print("description:" + node_name)
				desc_arr.append(node_name)
		
		if(in_title_node == true):
			# print("Title-data:"+ node_data)
			if(node_data !=""):
				title_arr.append(node_data)
			else:
				# print("Title:" + node_name)
				title_arr.append(node_name)
		
		if(in_link_node == true):
			# print("link-desc" + node_data)
			if(node_data != ""):
				link_arr.append(node_data)
			else:
				# print("link" + node_name)
				link_arr.append(node_name)


func _on_HTTPRequest_request_completed(_result, _response_code, _headers, body):
	$Background/ListOfTitles.clear()
	title_arr =  []
	desc_arr  =  []
	link_arr  =  []
	check_arr = []
	curIndex = 0
	
	parseArxiv(body,true)
	
	if $Background/ButtonList/filter/filterC.pressed:
		#var keywords = ['Space Debris','occultation','FRB','OSETI','SETI','VERITAS','MAGIC','Breakthrough','Intellegent Life','Gamma-Ray Burst','Nebula','HESS','Pulsar','GRB','Radio Burst']
		var keywords = []
		var listNum = filterListNode.get_item_count()
		for i in range(listNum):
			keywords.append(filterListNode.get_item_text(i))
		var passing_t = []
		var passing_l = []
		var passing_d = []
		for i in range(len(title_arr)):
			var doesPass = false
			for kw in keywords:
				if kw.to_lower() in title_arr[i].to_lower():
					doesPass = true
				if kw.to_lower() in desc_arr[i].to_lower():
					doesPass = true
			if doesPass:
				passing_t.append(title_arr[i])
				passing_d.append(desc_arr[i])
				passing_l.append(link_arr[i])
		title_arr = passing_t
		desc_arr = passing_d
		link_arr = passing_l
		
	
	check_arr = []
	for i in title_arr:
		check_arr.append(false)
		$Background/ListOfTitles.add_item(i,null,true)
	
	curIndex = 0
	$Background/OutputContainer/CheckRow/CheckBox.pressed = false


func _on_ListOfTitles_item_selected(index):
	curIndex = index
	$Background/OutputContainer/TitleRow/TitleBox.text = title_arr[index]
	$Background/OutputContainer/DescriptionBox/DescriptionBox.text = desc_arr[index]
	$Background/OutputContainer/LinkRow/LinkBox.text = link_arr[index]
	$Background/OutputContainer/CheckRow/CheckBox.pressed = check_arr[index]


func _on_OpenLink_button_up():
	var linkT = $Background/OutputContainer/LinkRow/LinkBox.text
	OS.shell_open(linkT)


func _on_CheckBox_toggled(button_pressed):
	if len(check_arr) > 0:
		check_arr[curIndex] = button_pressed


func _on_AddDatabase_button_up():
	saveData()
	

func loadFilters():
	var loadDataBase = File.new()
	
	# see if the file actually exists before opening it
	if !loadDataBase.file_exists("filters.dat"):
		return []
	
	var filterList = []
	# read the data in
	loadDataBase.open("filters.dat", File.READ)
	var text = loadDataBase.get_as_text()
	filterList = text.split("\n")
	loadDataBase.close()
	
	return filterList

func saveFilters():
	
	var filterList = []
	var listNum = filterListNode.get_item_count()
	
	for i in range(listNum):
		var fil = filterListNode.get_item_text(i)
		if not (fil in filterList):
			filterList.append(fil)
	
	var filterPool = PoolStringArray(filterList)
	var saveFilters = filterPool.join("\n")
	# create a file object
	var saveDataBase = File.new()
	saveDataBase.open("filters.dat", File.WRITE)
	saveDataBase.store_string(saveFilters)
	saveDataBase.close()
	
	return filterList


# this saves data from file
func saveData():
	var dbBuff = loadData()
	
	if dbBuff == null:
		dbBuff = []
	
	var ixx = 0
	for cV in check_arr:
		if cV:
			var di = {'title':title_arr[ixx],'desc':desc_arr[ixx],'link':link_arr[ixx]}
			dbBuff.append(di)
		ixx += 1
	
	# create a file object
	var saveDataBase = File.new()
	saveDataBase.open("database.json", File.WRITE)
	saveDataBase.store_string(to_json(dbBuff))
	saveDataBase.close()
	
	check_arr = []
	for i in title_arr:
		check_arr.append(false)
	$Background/OutputContainer/CheckRow/CheckBox.pressed = false


# this loads a the data from file
func loadData():
	# create a file object
	var loadDataBase = File.new()
	
	# see if the file actually exists before opening it
	if !loadDataBase.file_exists("database.json"):
		return null
	
	var dbData = []
	# read the data in
	loadDataBase.open("database.json", File.READ)
	var text = loadDataBase.get_as_text()
	var jsonR = JSON.parse(text)
	dbData = jsonR.result
	loadDataBase.close()
	
	return dbData


func _on_OpenDatabase_button_up():
	$Background/ListOfTitles.clear()
	var dbData = loadData()
	curIndex = 0
	title_arr =  []
	desc_arr  =  []
	link_arr  =  []
	for di in dbData:
		title_arr.append(di['title'])
		desc_arr.append(di['desc'])
		link_arr.append(di['link'])
	check_arr = []
	
	for i in title_arr:
		check_arr.append(false)
		$Background/ListOfTitles.add_item(i,null,true)
	
	$Background/OutputContainer/CheckRow/CheckBox.pressed = false


func _on_DirectAdd_button_up():
	$PopupPanel/popupHolder/popupstuff/LineEdit.text = ""
	$PopupPanel.popup()


func _on_popupInput_button_up():
	var allText = $PopupPanel/popupHolder/popupstuff/LineEdit.text
	$PopupPanel.hide()
	var regex = RegEx.new()
	regex.compile("\\d+.\\d+")
	var idArr = regex.search_all(allText)
	var idArrStr = []
	for id in idArr:
		idArrStr.append(id.get_string())
	var stIDA = PoolStringArray(idArrStr)
	var idList = stIDA.join(",")
	var lOS = stIDA.size() + 2
	$arxivDirect.request("http://export.arxiv.org/api/query?id_list=" + idList + "&start=0&max_results=" + str(lOS))
	if not $ArxivLookup.visible:
		$ArxivLookup.show()

func _on_arxivDirect_request_completed(_result,_response_code, _headers, body):
	$Background/ListOfTitles.clear()
	title_arr =  []
	desc_arr  =  []
	link_arr  =  []
	check_arr = []
	curIndex = 0
	
	#lets parse this body content
	parseArxiv(body,false)
	
	check_arr = []
	for i in title_arr:
		check_arr.append(false)
		$Background/ListOfTitles.add_item(i,null,true)
	
	curIndex = 0
	$Background/OutputContainer/CheckRow/CheckBox.pressed = false
	
	if $ArxivLookup.visible:
		$ArxivLookup.hide()


func _on_DeleteFilter_button_up():
	var listNum = filterListNode.get_item_count()
	
	var newList = []
	
	for i in range(listNum):
		var fil = filterListNode.is_selected(i)
		var filName = filterListNode.get_item_text(i)
		if not fil:
			newList.append(filName)
	
	filterListNode.clear()
	
	for nF in newList:
		filterListNode.add_item(nF)
	
	saveFilters()


func _on_AddFilter_button_up():
	var newFilter = $Background/ButtonList/NewFilter.text
	
	var listNum = filterListNode.get_item_count()
	
	var foFil = false
	for i in range(listNum):
		if newFilter == filterListNode.get_item_text(i):
			foFil = true
	
	if not foFil:
		filterListNode.add_item(newFilter)
	
	saveFilters()


func _on_Close_button_up():
	if $PopupPanel.is_visible():
		$PopupPanel.hide()


func _on_ArxivHTree_item_selected():
	var curName = getArxivSelected()
	
	var arxivH = getStoredArxivHeaders()
	var textStrings = []
	for i in arxivH:
		if i == curName:
			i = "*" + i
		textStrings.append(i)
	
	var saveDataBase = File.new()
	saveDataBase.open("arxiv_headers.json", File.WRITE)
	saveDataBase.store_string(to_json(textStrings))
	saveDataBase.close()
	


func _on_ADSClose_button_up():
	if $ADSPopup.is_visible():
		$ADSPopup.hide()


func _on_submitads_button_up():
	if $ADSPopup.is_visible():
		$ADSPopup.hide()
	var apiKey = $ADSPopup/Window/KeyInput/Key.text
	if apiKey == "":
		$ADSWarning.show()
		return
	
	var saveKey = File.new()
	saveKey.open("adsKey.dat", File.WRITE)
	saveKey.store_string(apiKey)
	saveKey.close()
	
	var allText = $ADSPopup/Window/popupstuff/input.text
	$ADSPopup.hide()
	var idArrStr = allText.split("\n",false)
	var header = "Authorization: Bearer:" + apiKey
	
	$Background/ListOfTitles.clear()
	title_arr =  []
	desc_arr  =  []
	link_arr  =  []
	check_arr = []
	curIndex = 0
	$ADSLookup.show()
	yield(adsRequestWrapper(idArrStr,header),"completed")
	$ADSLookup.hide()
	check_arr = []
	for i in title_arr:
		check_arr.append(false)
		$Background/ListOfTitles.add_item(i,null,true)
	
	curIndex = 0
	$Background/OutputContainer/CheckRow/CheckBox.pressed = false

var adsIsFinished = []
func adsRequestWrapper(idArr,header):
	adsIsFinished = []
	for idStr in idArr:
		var request = 'https://api.adsabs.harvard.edu/v1/search/query?q=bibcode%3A'+ idStr +'&fl=title,abstract,bibcode'
		$ADSRequest.request(request,[header])
		while true:
			yield(get_tree().create_timer(1.0), "timeout")
			#print("Finished ADS Requests : ",adsIsFinished)
			var finished = false
			if idStr in adsIsFinished:
				finished = true
			if finished:
				break
			
	print("ADS Finished")

func _on_ADSRequest_request_completed(result, response_code, headers, body):
	
	#lets parse this body content
	body = body.get_string_from_ascii()
	var parsedADS = JSON.parse(body)
	parsedADS = parsedADS.result
	
	var curRes = parsedADS['response']['docs'][0]
	title_arr.append(curRes['title'][0])
	desc_arr.append(curRes['abstract'])
	link_arr.append('https://ui.adsabs.harvard.edu/link_gateway/' + curRes['bibcode'] + '/PUB_PDF')
	adsIsFinished.append(curRes['bibcode'])


func _on_OpenADS_button_up():
	var loadKey = File.new()
	loadKey.open("adsKey.dat", File.READ)
	var apiKey = loadKey.get_as_text()
	loadKey.close()
	
	if apiKey != "":
		$ADSPopup/Window/KeyInput/Key.text = apiKey
	else:
		$ADSPopup/Window/KeyInput/Key.text = ""
	$ADSPopup/Window/popupstuff/input.text = ""
	$ADSPopup.popup()
