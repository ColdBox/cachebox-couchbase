component {

	public void function index(event, rc, prc) {
	}

	function eventTest(event,rc,prc) cache="true" cachetimeout="5"{
		sleep(2000);
	}
	
	function viewTest(event,rc,prc){
		return renderView(view="main/viewTest", cache=true);
	}
}