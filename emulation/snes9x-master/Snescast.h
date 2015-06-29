#ifndef SNESCAST_H
#define SNESCAST_H

#include "stdafx.h"
#include <Windows.h>
#include <ftd2xx.h>
#include <iostream>
#include <queue>
#include <mutex>

#define SERIAL "FTYJK7NM"
#define RXBUFF_SIZE 512

struct snesaccess_t {
	unsigned char addr;
	unsigned char data;
	bool read;
	bool apu;

	unsigned char seq;
};

struct msg {
	unsigned char data[RXBUFF_SIZE];
};

class Snescast {
private:
	FT_STATUS ftStatus;
	FT_HANDLE ftHandle1;
	
	unsigned int dword_buff, last_seq;
	snesaccess_t access_buff;
	std::queue<msg> buf;
	unsigned char curr_buff[RXBUFF_SIZE];
	int bufflevel, pushes = 0, pops = 0;
	bool device_opened = false;
	std::mutex              locker;
	bool Snescast::xfer_buffer();
public:
	Snescast();
	void open();
	void close();
	void clear_buffer();
	unsigned int getdword();
	unsigned int peekdword();
	void populate_buffers();
	unsigned int getbufsize();
};

snesaccess_t * format_snesaccess(unsigned int snes_pkt, snesaccess_t * dest);

extern Snescast dev;

#endif