import { Socket } from 'phoenix';
const socket = new Socket('/socket', {
  params: { token: window.userToken },
});
socket.connect();
const channel = socket.channel('room:lobby', {});
channel
  .join()
  .receive('ok', resp => {
    console.log('Joined successfully', resp);
  })
  .receive('error', resp => {
    console.log('Unable to join', resp);
  });

const chatForm = document.querySelector('#chat-form');

chatForm.addEventListener('submit', e => {
  e.preventDefault();
  channel.push('new_msg', { body: e.target[0].value });
});

channel.on('new_msg', ({ body }) => {
  console.log(body);
});

export default socket;
