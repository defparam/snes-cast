#include "Snescast.h"

Snescast::Snescast(void) {
	bufflevel = 0;
	memset(curr_buff, 0, RXBUFF_SIZE);
	last_seq = 0;
}

void Snescast::populate_buffers(){
	msg blah;
	int k;
	DWORD RxBytes;
	this->open();
	printf("Thread Test\n");
	printf("% ");


	while (1) {
		//if ((pushes % 1000) == 0) printf("PUSHES!: %d\n", pushes);
		if (!device_opened) continue;
		FT_GetQueueStatus(ftHandle1, &RxBytes);
		if (RxBytes >= RXBUFF_SIZE) {
			
			FT_Read(ftHandle1, blah.data, RXBUFF_SIZE, &RxBytes);
			locker.lock();
			buf.push(blah);
			pushes++;
			k = buf.size();
			if ((k > 0) && (k % 1000 == 0))printf("Warning: buf.size() is %d\n", k);
			locker.unlock();
		}
	}
}

bool Snescast::xfer_buffer() {
	locker.lock();
	if (bufflevel < 4) {
		if (buf.size() > 0) {
			for (int i = 0; i < RXBUFF_SIZE;i++) curr_buff[i] = (unsigned char) buf.front().data[i];
			bufflevel = RXBUFF_SIZE;
			
			buf.pop();
			
			pops++;
			//if ((pops % 1000) == 0) printf("POPS!  : %d\n", pops);

		}
		locker.unlock();
		return true;
		
	}
	else {
		locker.unlock();
		return false;
	}
}

void Snescast::clear_buffer() {
	locker.lock();
	std::queue<msg> empty;
	if (!buf.empty()) std::swap(buf, empty);
	locker.unlock();
}

unsigned int Snescast::peekdword() {
	unsigned int peek_val;
	if (bufflevel < 4) {
		if (!xfer_buffer()) return 0xFFFFFFFF;
	}

	peek_val = 0;
	peek_val |= curr_buff[(RXBUFF_SIZE - bufflevel)] << 24;
	peek_val |= curr_buff[(RXBUFF_SIZE - bufflevel) + 1] << 16;
	peek_val |= curr_buff[(RXBUFF_SIZE - bufflevel) + 2] << 8;
	peek_val |= curr_buff[(RXBUFF_SIZE - bufflevel) + 3];

	return peek_val;
}

unsigned int Snescast::getdword() {
	unsigned int get_val;
	get_val = peekdword();
	if (get_val != 0xFFFFFFFF) bufflevel = bufflevel - 4;
	return get_val;
}

unsigned int Snescast::getbufsize() {
	if (bufflevel < 4) xfer_buffer();
	return bufflevel;
}


void Snescast::close(void) {
	device_opened = false;
	FT_Close(&ftHandle1); 
}

void Snescast::open(void) {
	ftStatus = FT_OpenEx((PVOID)SERIAL, FT_OPEN_BY_SERIAL_NUMBER, &ftHandle1);
	if (ftStatus == FT_OK) {
		device_opened = true;
		printf("FTDI Device: %s is now open.\n", SERIAL);
	}
	else {
		printf("Failed to open FTDI Device: %s\n", SERIAL);
	}
	FT_SetBitMode(ftHandle1, 0x00, 0x00);
	FT_SetBitMode(ftHandle1, 0x00, 0x40);
	ftStatus = FT_Purge(ftHandle1, FT_PURGE_RX | FT_PURGE_TX);
}


snesaccess_t * format_snesaccess(unsigned int snes_pkt, snesaccess_t * dest) {
	unsigned char desc;
	dest->data = (snes_pkt>>16)&0xFF;
	dest->addr = (snes_pkt >> 24) & 0xFF;
	desc = (snes_pkt >> 8) & 0xFF;
	dest->seq = (snes_pkt >> 12) & 0xF;

	if ((snes_pkt & 0xFF) != 0xFF) printf("Marker Error on PKT processing, got: 0x%02x\n", snes_pkt & 0xFF);

	if ((desc & 0x2) == 0x2) dest->read = true;
	else dest->read = false;

	if ((desc & 0x8) == 0x8) dest->addr = 0xFF;
	if ((desc & 0x4) == 0x4) dest->data = 0xFF;
	if (dest->addr == 0x40 || dest->addr == 0x41 || dest->addr == 0x42 || dest->addr == 0x43) dest->apu = true;
	else dest->apu = false;

	

	return dest;
}